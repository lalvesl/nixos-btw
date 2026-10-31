# sbx: a per-project KVM sandbox for running and hacking on untrusted code
# (build.rs, proc-macros, zig build scripts, npm postinstall, random binaries).
#
# A VM rather than a container: build scripts run arbitrary code, and with a
# shared kernel one local root exploit would be enough to reach the host.
#
# What the guest can reach:
#   - the project folder, writable. Anything in it may have been rewritten by
#     the code: .git/hooks, .envrc, .cargo/config.toml, flake.nix. Treat it
#     as untrusted before running anything from it on the host.
#   - the internet, through its own tap and NAT. Never the host itself, the
#     LAN, the tailnet or another sandbox (firewall below).
# What it cannot reach: the host /nix/store, $HOME, ~/.claude, the SSH agent,
# the host display. Each project has its own store, home and caches; nothing
# is shared between projects. The host evaluates no Nix code from the
# project; a project's flake is evaluated inside its guest only.
#
# Per-project state lives in ~/.cache/sbx/vms/<project>-<hash>: a root disk
# (copy-on-write over the base image, holding the project's own /nix/store)
# and a home disk. The VM keeps running after you leave, so entering again is
# just an SSH session over vsock on a kept-open connection.
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Concurrent sandboxes; one tap and one /30 each
  slots = 4;
  subnet = "10.77.0.0/16";

  # One guest build: the VM runner and the base image it boots from. A project
  # pins the one it was created with (a GC root in its cache dir), since its
  # root disk is an overlay of exactly that image.
  mkGuest =
    ai:
    let
      guest =
        (inputs.nixpkgs.lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          specialArgs = {
            inherit inputs;
            sbxAi = ai;
          };
          modules = [ ./guest.nix ];
        }).config.system.build;
    in
    pkgs.linkFarm "sbx-guest${lib.optionalString (!ai) "-noai"}" {
      run = "${guest.vm}/bin/run-sbx-vm";
      "disk.qcow2" = "${guest.sbxImage}/nixos.qcow2";
    };

  sbx = pkgs.writeShellApplication {
    name = "sbx";
    runtimeInputs = with pkgs; [
      coreutils
      e2fsprogs
      gawk
      nix
      openssh
      qemu-utils
      socat
      systemd
      util-linux
      virt-viewer
    ];
    runtimeEnv = {
      SBX_GUEST_AI = mkGuest true;
      SBX_GUEST_NOAI = mkGuest false;
      SBX_SLOTS = toString slots;
    };
    text = builtins.readFile ./sbx.sh;
  };

  slotIds = lib.range 0 (slots - 1);

  # Destinations a guest may never reach through the host
  blocked = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "100.64.0.0/10" # tailnet
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16" # LAN, and the home server's subnet route
    "224.0.0.0/4"
    "240.0.0.0/4"
  ];
in
{
  environment.systemPackages = [ sbx ];
  system.build.sbx = sbx;

  # Persistent taps owned by the user, so QEMU attaches without root. Each is
  # its own point-to-point /30: host .1, guest .2. No bridge, so sandboxes
  # cannot see each other.
  networking.interfaces = lib.listToAttrs (
    map (
      n:
      lib.nameValuePair "sbx${toString n}" {
        virtual = true;
        virtualType = "tap";
        virtualOwner = "lalvesl";
        ipv4.addresses = [
          {
            address = "10.77.${toString n}.1";
            prefixLength = 30;
          }
        ];
      }
    ) slotIds
  );
  networking.networkmanager.unmanaged = [ "interface-name:sbx*" ];

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  networking.firewall.extraCommands = ''
    # sbx: guests get NAT to the internet and nothing else
    iptables -w -t nat -N sbx-nat 2>/dev/null || true
    iptables -w -t nat -F sbx-nat
    iptables -w -t nat -A sbx-nat -s ${subnet} ! -d ${subnet} -j MASQUERADE
    iptables -w -t nat -D POSTROUTING -j sbx-nat 2>/dev/null || true
    iptables -w -t nat -A POSTROUTING -j sbx-nat

    ip46tables -N sbx-fwd 2>/dev/null || true
    ip46tables -F sbx-fwd
    # Into a guest: only replies (the host reaches it over vsock, not routing)
    ip46tables -A sbx-fwd -o sbx+ -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ip46tables -A sbx-fwd -o sbx+ -j DROP
    ip6tables -w -A sbx-fwd -i sbx+ -j DROP
    ${lib.concatMapStrings (net: ''
      iptables -w -A sbx-fwd -i sbx+ -d ${net} -j DROP
    '') blocked}
    iptables -w -A sbx-fwd -i sbx+ -j ACCEPT
    ip46tables -D FORWARD -j sbx-fwd 2>/dev/null || true
    ip46tables -I FORWARD -j sbx-fwd

    # To the host itself: replies only. Inserted in reverse, so the ACCEPT ends
    # up first; nixos-fw is rebuilt on every reload, so this never piles up.
    ip46tables -I nixos-fw -i sbx+ -j DROP
    ip46tables -I nixos-fw -i sbx+ -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  '';

  networking.firewall.extraStopCommands = ''
    iptables -w -t nat -D POSTROUTING -j sbx-nat 2>/dev/null || true
    ip46tables -D FORWARD -j sbx-fwd 2>/dev/null || true
  '';
}
