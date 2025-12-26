# sbx (sandbox): enter an isolated NixOS VM for the project in the current
# directory. Design and threat model: nixos/modules/sandbox/default.nix.
#
# Provided by the Nix wrapper: SBX_GUEST_AI, SBX_GUEST_NOAI (guest builds:
# `run` and `disk.qcow2`) and SBX_SLOTS (how many sbxN taps the host has).

usage() {
  cat <<'EOF'
Usage:
  sbx [options] [dir] [-- cmd...]  Enter the sandbox for dir (default: the
                                   project around $PWD), booting it if needed
  sbx --up [options] [dir]         Boot without entering
  sbx -p SPEC... [dir]             Forward guest ports to 127.0.0.1, any time;
                                   SPEC is PORT[:GUEST][/udp]
  sbx --close SPEC... [dir]        Stop forwarding
  sbx --gui [dir]                  Start sway in the guest, open the SPICE view
  sbx --stop [ID|dir...] | --all   Shut down (disks are kept)
  sbx --rm [ID|dir...]             Shut down and delete the disks
  sbx --upgrade [dir]              Move to the current guest build: rebuilds the
                                   root disk (store, system), keeps /home
  sbx --ls                         List sandboxes (ID first; no header in a pipe)

Options:
  --no-ai          No claude-code, no AI plugins in nvim (its own VM and disks)
  --offline        No network at all (TCP ports still work, over SSH);
                   --online undoes it. Both apply when the VM boots
  --fresh          Delete this sandbox's disks before booting
  --reload         Rebuild the cached dev shell on entry
  --mem SIZE       Guest memory, QEMU syntax (default 8G)
  --cpus N         Guest vCPUs (default 4)

Clipboard: yanks in nvim and `cmd | clip` in the guest reach the host
clipboard (OSC 52); paste into the guest with ctrl+shift+v.

Example: sbx --ls | awk '{print $1}' | xargs sbx --rm
EOF
}

die() {
  echo "sbx: $*" >&2
  exit 1
}

# ExecStop of the VM unit: ask the guest to power off and wait for QEMU, so
# the disks are never cut off mid-write
if [ "${1:-}" = _powerdown ]; then
  printf '%s\n' '{"execute":"qmp_capabilities"}' '{"execute":"system_powerdown"}' |
    socat -t 2 - "UNIX-CONNECT:$2" >/dev/null 2>&1 || exit 0
  for _ in $(seq 60); do
    kill -0 "${MAINPID:-0}" 2>/dev/null || exit 0
    sleep 0.5
  done
  exit 0
fi

cache_root=${XDG_CACHE_HOME:-$HOME/.cache}/sbx
run_root=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is not set}/sbx
disk_size=64G

action=enter
ai=1
net=
fresh=
reload=
mem=
cpus=
all=
dir=
ports=()
targets=()

set_action() {
  [ "$action" = enter ] || [ "$action" = "$1" ] || die "--$action and --$1 do not mix"
  action=$1
}

while [ "$#" -gt 0 ]; do
  case $1 in
  --up) set_action up ;;
  -p | --port) set_action port ;;
  --close) set_action close ;;
  --gui) set_action gui ;;
  --stop) set_action stop ;;
  --rm) set_action rm ;;
  --upgrade) set_action upgrade ;;
  --ls) set_action ls ;;
  --all) all=1 ;;
  --no-ai) ai= ;;
  --offline) net=offline ;;
  --online) net=online ;;
  --fresh) fresh=1 ;;
  --reload) reload=1 ;;
  --mem)
    mem=${2:?--mem needs a value}
    shift
    ;;
  --cpus)
    cpus=${2:?--cpus needs a value}
    shift
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  --)
    shift
    break
    ;;
  -*) die "unknown option $1 (see sbx --help)" ;;
  *)
    case $action in
    port | close) if [ -d "$1" ]; then dir=$1; else ports+=("$1"); fi ;;
    stop | rm) targets+=("$1") ;;
    *)
      [ -z "$dir" ] && [ -d "$1" ] || die "not a directory: $1"
      dir=$1
      ;;
    esac
    ;;
  esac
  shift
done

# The project is the nearest parent holding .git or flake.nix, else the
# directory itself. Found without running git: its config is untrusted.
find_root() {
  local d=$1
  while [ "$d" != / ]; do
    if [ -e "$d/.git" ] || [ -e "$d/flake.nix" ]; then
      echo "$d"
      return
    fi
    d=$(dirname "$d")
  done
  echo "$1"
}

ssh_key=$cache_root/id_ed25519
socat_bin=$(command -v socat)
ssh_bin=$(command -v ssh)
rm_bin=$(command -v rm)
self=$(realpath "$0")

set_id() {
  id=$1
  unit=sbx-$id.service
  vm=$cache_root/vms/$id
  run=$run_root/$id
}

# Sets root, rel and the id paths for a project directory
select_project() {
  local start name hash
  start=$(realpath "${1:-${dir:-$PWD}}")
  root=$(find_root "$start")
  if [ "$root" = "$HOME" ] || [ "$root" = / ]; then
    die "refusing to share $root itself; cd into a project"
  fi
  rel=${start#"$root"}
  rel=${rel#/}
  name=$(basename "$root" | tr -cd 'A-Za-z0-9_.-' | cut -c1-32)
  hash=$(printf '%s' "$root" | sha256sum | cut -c1-8)
  set_id "${name:-project}-$hash"
  [ -n "$ai" ] || set_id "$id-noai"
}

# A --stop/--rm argument: an ID from `sbx --ls`, or a directory
select_target() {
  if [ -d "$cache_root/vms/$1" ] && [[ $1 != */* ]]; then
    set_id "$1"
  elif [ -d "$1" ]; then
    select_project "$1"
  else
    die "no sandbox or directory called $1"
  fi
}

is_running() {
  systemctl --user is-active --quiet "$1"
}

load_slot() {
  slot=$(cat "$run/meta/slot")
  cid=$((7700 + slot))
  # Options first: for ssh the first value given wins
  ssh_base=("$ssh_bin" -F /dev/null -l dev
    -i "$ssh_key" -o IdentitiesOnly=yes -o IdentityAgent=none
    -o "UserKnownHostsFile=$vm/known_hosts" -o StrictHostKeyChecking=accept-new
    -o "HostKeyAlias=sbx-$id"
    -o "ProxyCommand=$socat_bin - VSOCK-CONNECT:$cid:22"
    -o ForwardAgent=no -o ForwardX11=no -o LogLevel=ERROR -o ServerAliveInterval=30)
  ssh_cmd=("${ssh_base[@]}" -o ControlMaster=auto -o "ControlPath=$run/ssh.ctl" -o ControlPersist=30m)
}

take_slot() {
  local n owner
  mkdir -p "$run_root/slots"
  for ((n = 0; n < SBX_SLOTS; n++)); do
    owner=$(cat "$run_root/slots/$n/owner" 2>/dev/null || true)
    if [ -n "$owner" ] && ! is_running "sbx-$owner.service"; then
      rm -rf "$run_root/slots/$n"
    fi
    if mkdir "$run_root/slots/$n" 2>/dev/null; then
      echo "$id" >"$run_root/slots/$n/owner"
      echo "$n"
      return
    fi
  done
  die "all $SBX_SLOTS slots are in use; free one with sbx --stop"
}

# Root disk: a copy-on-write overlay of the pinned guest's base image. The
# pin is a GC root, so a host rebuild cannot collect the image underneath.
make_root_disk() {
  local guest=$1
  rm -f "$vm/disk.qcow2" "$vm/guest" "$vm/known_hosts"
  nix-store --add-root "$vm/guest" --realise "$guest" >/dev/null
  qemu-img create -q -f qcow2 -b "$(realpath "$vm/guest/disk.qcow2")" -F qcow2 \
    "$vm/disk.qcow2" "$disk_size"
}

make_home_disk() {
  local raw=$vm/home.raw
  qemu-img create -q -f raw "$raw" "$disk_size"
  mkfs.ext4 -q -L sbx-home "$raw"
  qemu-img convert -f raw -O qcow2 "$raw" "$vm/home.qcow2"
  rm -f "$raw"
}

boot() {
  local guest_now
  if [ -n "$ai" ]; then guest_now=$SBX_GUEST_AI; else guest_now=$SBX_GUEST_NOAI; fi

  if is_running "$unit"; then
    [ -z "$fresh" ] || die "$id is running; sbx --stop it before --fresh"
    load_slot
    if [ -n "$net" ] && [ "$(cat "$run/meta/net")" != "$net" ]; then
      echo "sbx: running $(cat "$run/meta/net"); sbx --stop first to change that" >&2
    fi
    return
  fi

  net=${net:-online}
  [ -f "$ssh_key" ] || {
    mkdir -p "$cache_root"
    ssh-keygen -q -t ed25519 -N '' -C sbx -f "$ssh_key"
  }
  if [ -n "$fresh" ]; then
    rm -rf "$vm"
  fi
  mkdir -p "$vm/tmp"
  printf '%s\n' "$root" >"$vm/project"
  if [ ! -e "$vm/disk.qcow2" ] || [ ! -e "$vm/guest" ]; then
    make_root_disk "$guest_now"
  elif [ "$(realpath "$vm/guest")" != "$guest_now" ]; then
    echo "sbx: a newer guest build exists; sbx --upgrade moves to it (keeps /home)" >&2
  fi
  [ -e "$vm/home.qcow2" ] || make_home_disk

  if [ "$net" = online ] && [ ! -e /sys/class/net/sbx0 ]; then
    die "the host has no sbx taps yet; switch to the new system first, or use --offline"
  fi

  local slot_n started
  slot_n=$(take_slot)
  rm -rf "$run"
  mkdir -p "$run/meta"
  cp "$ssh_key.pub" "$run/meta/authorized_keys"
  echo "$slot_n" >"$run/meta/slot"
  echo "$net" >"$run/meta/net"
  basename "$root" >"$run/meta/name"
  # QEMU option strings split on commas; this path never has any
  ln -s "$root" "$run/src"
  load_slot

  local args=(
    -display none -vga none -device virtio-vga
    -spice "unix=on,addr=$run/spice.sock,disable-ticketing=on"
    -device "vhost-vsock-pci,guest-cid=$cid"
    -qmp "unix:$run/qmp.sock,server=on,wait=off"
    -serial "file:$vm/console.log"
    -drive "file=$vm/home.qcow2,if=none,id=home,format=qcow2,cache=writeback,werror=report"
    -device "virtio-blk-pci,drive=home,serial=home"
    -virtfs "local,path=$run/src,mount_tag=src,security_model=none"
    -virtfs "local,path=$run/meta,mount_tag=sbxmeta,security_model=none,readonly=on"
  )
  if [ "$net" = online ]; then
    args+=(-netdev "tap,id=net0,ifname=sbx$slot,script=no,downscript=no"
      -device "virtio-net-pci,netdev=net0")
  else
    args+=(-nic none)
  fi
  [ -z "$mem" ] || args+=(-m "$mem")
  [ -z "$cpus" ] || args+=(-smp "$cpus")

  started=$(date +%s)
  echo "sbx: booting $id ($net${ai:+, ai})..." >&2
  systemd-run --user --quiet --collect --unit "$unit" \
    --description "sbx sandbox for $root" \
    -p KillMode=mixed -p TimeoutStopSec=40 \
    -p "ExecStop=$self _powerdown $run/qmp.sock" \
    -p "ExecStopPost=$rm_bin -rf $run_root/slots/$slot" \
    --setenv=NIX_DISK_IMAGE="$vm/disk.qcow2" \
    --setenv=TMPDIR="$vm/tmp" --setenv=USE_TMPDIR=1 \
    "$vm/guest/run" "${args[@]}"

  for _ in $(seq 240); do
    if "${ssh_cmd[@]}" -o ConnectTimeout=2 sbx true 2>/dev/null; then
      echo "sbx: up. It keeps running after you leave; sbx --stop shuts it down." >&2
      return
    fi
    if ! is_running "$unit"; then
      journalctl --user -u "$unit" --since "@$started" -o cat --no-pager >&2 || true
      # The serial console carries terminal escapes; keep the text only
      tail -n 20 "$vm/console.log" | tr -cd '[:print:]\n' >&2 || true
      die "the VM exited while booting"
    fi
    sleep 0.5
  done
  die "no SSH after 2 minutes; see $vm/console.log"
}

forward() {
  local spec=$1 proto=tcp host guest punit
  case $spec in
  */udp)
    proto=udp
    spec=${spec%/udp}
    ;;
  */tcp) spec=${spec%/tcp} ;;
  esac
  host=${spec%%:*}
  guest=${spec#*:}
  [[ $host =~ ^[0-9]+$ && $guest =~ ^[0-9]+$ ]] || die "bad port spec: $1"
  punit=sbx-$id-$proto-$host.service

  if [ "$action" = close ]; then
    systemctl --user stop "$punit" 2>/dev/null || true
    echo "sbx: closed 127.0.0.1:$host ($proto)"
    return
  fi
  if is_running "$punit"; then
    echo "sbx: 127.0.0.1:$host ($proto) is already forwarded"
    return
  fi

  # TCP rides SSH, so it reaches services bound to the guest's localhost and
  # works offline. UDP cannot, so it goes to the guest address on the tap.
  # Either way the forward dies with the VM.
  if [ "$proto" = tcp ]; then
    systemd-run --user --quiet --collect --unit "$punit" \
      -p "BindsTo=$unit" -p "After=$unit" -p Restart=on-failure -p RestartSec=2 \
      "${ssh_base[@]}" -o ControlMaster=no -o ExitOnForwardFailure=yes \
      -N -L "127.0.0.1:$host:127.0.0.1:$guest" sbx
  else
    [ "$(cat "$run/meta/net")" = online ] || die "UDP needs the network; the VM is --offline"
    systemd-run --user --quiet --collect --unit "$punit" \
      -p "BindsTo=$unit" -p "After=$unit" \
      "$socat_bin" "UDP4-LISTEN:$host,bind=127.0.0.1,fork,reuseaddr" "UDP4:10.77.$slot.2:$guest"
  fi
  echo "sbx: 127.0.0.1:$host -> guest :$guest ($proto)"
}

list() {
  local d vid state
  [ -t 1 ] && printf '%-48s %-8s %-6s %s\n' ID STATE DISK PROJECT
  for d in "$cache_root"/vms/*/; do
    [ -d "$d" ] || continue
    vid=$(basename "$d")
    state=stopped
    is_running "sbx-$vid.service" && state=running
    printf '%-48s %-8s %-6s %s\n' "$vid" "$state" \
      "$(du -sh "$d" 2>/dev/null | cut -f1)" "$(cat "$d/project" 2>/dev/null)"
  done
}

case $action in
ls) list ;;
stop | rm)
  if [ -n "$all" ]; then
    systemctl --user stop 'sbx-*.service'
    [ "$action" = stop ] || rm -rf "$cache_root/vms"
    exit 0
  fi
  [ "${#targets[@]}" -gt 0 ] || targets=("${dir:-$PWD}")
  for t in "${targets[@]}"; do
    select_target "$t"
    systemctl --user stop "$unit" 2>/dev/null || true
    if [ "$action" = rm ]; then
      rm -rf "$vm"
      echo "sbx: deleted $id"
    fi
  done
  ;;
upgrade)
  select_project
  if is_running "$unit"; then
    systemctl --user stop "$unit"
  fi
  [ -d "$vm" ] || die "no sandbox for $root yet"
  if [ -n "$ai" ]; then make_root_disk "$SBX_GUEST_AI"; else make_root_disk "$SBX_GUEST_NOAI"; fi
  echo "sbx: $id now boots the current guest; /home was kept" >&2
  ;;
enter | up | port | close | gui)
  select_project
  boot
  case $action in
  port | close)
    [ "${#ports[@]}" -gt 0 ] || die "which port? e.g. sbx -p 8080"
    for p in "${ports[@]}"; do forward "$p"; done
    ;;
  gui)
    "${ssh_cmd[@]}" sbx sudo systemctl start sbx-gui
    setsid -f remote-viewer --title "sbx: $id" "spice+unix://$run/spice.sock" >/dev/null 2>&1
    ;;
  enter)
    remote=$(printf '%q ' sbx-enter "$rel" ${reload:+reload} -- "$@")
    tty=-T
    [ -t 0 ] && tty=-t
    exec "${ssh_cmd[@]}" "$tty" sbx "$remote"
    ;;
  esac
  ;;
esac
