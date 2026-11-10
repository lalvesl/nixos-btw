# wifi-hotspot: share the current Wi-Fi connection through a second network on
# the same card. HOTSPOT_SSID and HOTSPOT_COUNTRY come from wifi-hotspot.nix.
#
#   wifi-hotspot check      only test whether a hotspot is possible (no root)
#   sudo wifi-hotspot       start it (Ctrl+C stops it and undoes everything)
#   sudo wifi-hotspot password   print the hotspot passphrase

usage() {
  echo "usage: wifi-hotspot [start|check|password]"
}

cmd=${1:-start}
case "$cmd" in
  start | check | password) ;;
  -h | --help | help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if [ "$cmd" != check ] && [ "$(id -u)" -ne 0 ]; then
  echo "run with sudo: sudo wifi-hotspot $cmd" >&2
  exit 1
fi

state_dir=/var/lib/wifi-hotspot
run_dir=/run/wifi-hotspot
pass_file=$state_dir/passphrase

if [ "$cmd" = password ]; then
  if [ -s "$pass_file" ]; then cat "$pass_file"; else
    echo "no passphrase yet: start the hotspot once" >&2
    exit 1
  fi
  exit 0
fi

# --- what is the card doing now -------------------------------------------
sta=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" { print $1; exit }')
if [ -z "$sta" ]; then
  echo "not possible to make a hotspot: this machine is not connected to a Wi-Fi network" >&2
  exit 1
fi
conn=$(nmcli -g GENERAL.CONNECTION device show "$sta")
phy=phy$(iw dev "$sta" info | awk '/wiphy/ { print $2; exit }')

link_freq() { iw dev "$sta" link | awk '/freq:/ { printf "%d", $2; exit }'; }
ssid=$(iw dev "$sta" link | sed -n 's/^[[:space:]]*SSID: //p')
freq=$(link_freq)

freq_to_chan() {
  if [ "$1" -eq 2484 ]; then echo 14
  elif [ "$1" -lt 2484 ]; then echo $((($1 - 2407) / 5))
  else echo $((($1 - 5000) / 5)); fi
}
band_of() { if [ "$1" -lt 3000 ]; then echo 2.4; else echo 5; fi; }

# An access point may only use a channel the card can start a network on: not
# disabled, and no "no IR" / radar-detection flag (DFS channels need radar
# handling that most Wi-Fi drivers, Intel's included, do not provide).
can_host() {
  local line
  line=$(iw phy "$phy" info | grep -E "^[[:space:]]*\* $1(\.0)? MHz" | head -1 || true)
  [ -n "$line" ] || return 1
  case "$line" in
    *"no IR"* | *disabled* | *radar*) return 1 ;;
  esac
  return 0
}

# --- can the card do both at once ----------------------------------------
if ! iw phy "$phy" info | grep -Eq '#\{[^}]*managed[^}]*AP[^}]*\}|#\{[^}]*managed[^}]*\}.*#\{[^}]*\<AP\>'; then
  echo "not possible to make a hotspot: this Wi-Fi card cannot run an access point and a connection at the same time" >&2
  exit 1
fi

chan=$(freq_to_chan "$freq")
echo "connected to '$ssid' on channel $chan ($freq MHz)"

pin_bssid=
if can_host "$freq"; then
  echo "channel $chan can host a hotspot"
else
  echo "channel $chan cannot host a hotspot here; looking for another channel of '$ssid'..."
  found=
  candidates=$(nmcli -t -f SSID,BSSID,FREQ,SIGNAL device wifi list ifname "$sta" --rescan yes |
    sed 's/\\:/-/g' |
    awk -F: -v s="$ssid" '$1 == s { split($3, f, " "); print $4, f[1], $2 }' |
    sort -rn || true)
  while read -r _ f b; do
    [ -n "${f:-}" ] || continue
    if can_host "$f"; then
      found=$f
      pin_bssid=$(echo "$b" | tr '-' ':')
      break
    fi
  done <<<"$candidates"
  if [ -z "$found" ]; then
    echo "not possible to make a hotspot for the current Wi-Fi (channel $chan is not supported to share, and '$ssid' has no other channel that is)" >&2
    exit 1
  fi
  echo "found it on channel $(freq_to_chan "$found") ($found MHz), access point $pin_bssid"
fi

if [ "$cmd" = check ]; then
  echo "a hotspot is possible${pin_bssid:+ (it would move the connection to $pin_bssid first)}"
  exit 0
fi

# --- start -----------------------------------------------------------------
old_bssid=$(nmcli -g 802-11-wireless.bssid connection show "$conn" || true)
cleanup() {
  if [ -n "$pin_bssid" ]; then
    nmcli connection modify "$conn" 802-11-wireless.bssid "$old_bssid" || true
  fi
  rm -rf "$run_dir"
}
trap cleanup EXIT

if [ -n "$pin_bssid" ]; then
  echo "moving the connection to $pin_bssid (the Wi-Fi drops for a few seconds)"
  nmcli connection modify "$conn" 802-11-wireless.bssid "$pin_bssid"
  nmcli connection up "$conn" >/dev/null
  freq=
  for _ in $(seq 30); do
    freq=$(link_freq)
    [ -n "$freq" ] && can_host "$freq" && break
    sleep 1
  done
  if [ -z "$freq" ] || ! can_host "$freq"; then
    echo "not possible to make a hotspot for the current Wi-Fi (could not move to a channel that can host one)" >&2
    exit 1
  fi
  chan=$(freq_to_chan "$freq")
fi

mkdir -p "$state_dir" "$run_dir"
chmod 700 "$state_dir" "$run_dir"
if [ ! -s "$pass_file" ]; then
  head -c 24 /dev/urandom | base64 | tr -d '/+=' | cut -c1-12 >"$pass_file"
fi
chmod 600 "$pass_file"

cat >"$run_dir/create_ap.conf" <<CONF
WIFI_IFACE=$sta
INTERNET_IFACE=$sta
SSID=$HOTSPOT_SSID
PASSPHRASE=$(cat "$pass_file")
CHANNEL=$chan
FREQ_BAND=$(band_of "$freq")
COUNTRY=$HOTSPOT_COUNTRY
NO_HAVEGED=1
CONF
chmod 600 "$run_dir/create_ap.conf"

echo
echo "starting '$HOTSPOT_SSID' on channel $chan"
echo "passphrase: sudo wifi-hotspot password"
echo "Ctrl+C stops it."
create_ap --config "$run_dir/create_ap.conf"
