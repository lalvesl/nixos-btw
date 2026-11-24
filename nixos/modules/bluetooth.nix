{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Share this machine's internet over Bluetooth (PAN / NAP), like a phone's
  # "Bluetooth tethering". Turn off to remove the bridge, the DHCP server and
  # the NAT rules. Pair the client once (bluetoothctl or blueman), then on the
  # client choose "Connect to > Network Access Point".
  # Off for now: the Samsung phone's Bluetooth stack restarts as soon as it tries
  # to join (no BNEP request ever reaches this machine), so USB tethering is used.
  hotspot = false;

  bridge = "br-bt";
  subnet = "10.42.7.0/24";
  gateway = "10.42.7.1";
  # systemd escapes the dash in the device unit name (br-bt -> br\x2dbt).
  bridgeDevice = "sys-subsystem-net-devices-${lib.replaceStrings [ "-" ] [ "\\x2d" ] bridge}.device";
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        ControllerMode = "bredr";
        Enable = "Source,Sink,Media,Socket";
        Disable = "Headset,Sink";
        Experimental = true;
      };
    };
  };

  services.blueman.enable = true;

  # The bridge and its DHCP server are networkd's; it only touches the
  # interfaces it has a .network file for, so NetworkManager keeps everything
  # else. Each connected device shows up as a bnep port on the bridge.
  systemd.network = lib.mkIf hotspot {
    enable = true;
    # Nothing here is needed for the machine to count as online.
    wait-online.enable = false;
    netdevs."40-${bridge}".netdevConfig = {
      Kind = "bridge";
      Name = bridge;
    };
    networks."40-${bridge}" = {
      matchConfig.Name = bridge;
      address = [ "${gateway}/24" ];
      networkConfig = {
        DHCPServer = true;
        ConfigureWithoutCarrier = true;
      };
      dhcpServerConfig = {
        PoolOffset = 10;
        PoolSize = 50;
        EmitDNS = true;
        DNS = [
          "1.1.1.1"
          "8.8.8.8"
        ];
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  networking.networkmanager.unmanaged = lib.mkIf hotspot [
    "interface-name:${bridge}"
    "interface-name:bnep*"
  ];

  # Forwarding is already on (sandbox module); this only adds NAT and lets the
  # clients ask for an address and a DNS answer. Same shape as the sbx rules.
  networking.firewall.interfaces.${bridge} = lib.mkIf hotspot {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = lib.mkIf hotspot true;

  networking.firewall.extraCommands = lib.mkIf hotspot ''
    iptables -w -t nat -N btap-nat 2>/dev/null || true
    iptables -w -t nat -F btap-nat
    iptables -w -t nat -A btap-nat -s ${subnet} ! -d ${subnet} -j MASQUERADE
    iptables -w -t nat -D POSTROUTING -j btap-nat 2>/dev/null || true
    iptables -w -t nat -A POSTROUTING -j btap-nat

    iptables -w -N btap-fwd 2>/dev/null || true
    iptables -w -F btap-fwd
    iptables -w -A btap-fwd -i ${bridge} -j ACCEPT
    iptables -w -A btap-fwd -o ${bridge} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -w -D FORWARD -j btap-fwd 2>/dev/null || true
    iptables -w -I FORWARD -j btap-fwd
  '';

  networking.firewall.extraStopCommands = lib.mkIf hotspot ''
    iptables -w -t nat -D POSTROUTING -j btap-nat 2>/dev/null || true
    iptables -w -D FORWARD -j btap-fwd 2>/dev/null || true
  '';

  # Registers the NAP profile with BlueZ on the bridge; without it a phone
  # pairs but has no "internet access" service to connect to.
  systemd.services.bluetooth-hotspot = lib.mkIf hotspot {
    description = "Bluetooth network access point on ${bridge}";
    after = [
      "bluetooth.service"
      bridgeDevice
    ];
    requires = [ "bluetooth.service" ];
    bindsTo = [ bridgeDevice ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bluez-tools}/bin/bt-network --server nap ${bridge}";
      Restart = "on-failure";
      RestartSec = 3;
    };
  };
}
