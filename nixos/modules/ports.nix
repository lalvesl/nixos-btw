{ pkgs, ... }:
let
  expose = pkgs.writeShellApplication {
    name = "expose";
    runtimeInputs = with pkgs; [
      socat
      iptables
      iproute2
      gawk
      gnugrep
      coreutils
      procps
    ];
    text = ''
            if [ "$(id -u)" -ne 0 ]; then
              exec sudo "$0" "$@"
            fi

            show_help() {
              cat << 'EOF'
      Usage:
        sudo expose <ip>:<port>                  Forward local <port> to <remote_ip>:<port> (and open firewall)
        sudo expose <local_port>:<ip>:<port>     Forward <local_port> to <remote_ip>:<port> (and open firewall)
        sudo expose <local_port> <ip>:<port>     Forward <local_port> to <remote_ip>:<port> (and open firewall)
        sudo expose <port>[/tcp|/udp]            Temporarily open firewall port for local services
        sudo expose close <port>                 Close a temporarily opened firewall port
        sudo expose list                         Show active temporary firewall rules and forwards

      Options:
        -u, --udp                                Use UDP instead of TCP (default is TCP)
        -d, -b, --daemon, --background           Run forward in background (daemon mode)
        -h, --help                               Show this help message

      Examples:
        sudo expose 192.168.100.16:9090          # Expose remote 192.168.100.16:9090 on local port 9090
        sudo expose 8080:192.168.100.16:9090     # Expose remote 192.168.100.16:9090 on local port 8080
        sudo expose 3000                         # Open local port 3000 in firewall for LAN devices
        sudo expose close 9090                   # Close port 9090 and stop its forward
        sudo expose list                         # List active rules
      EOF
            }

            CHAIN=""
            get_chain() {
              if [ -n "$CHAIN" ]; then
                return
              fi
              if iptables -n -L nixos-fw >/dev/null 2>&1; then
                CHAIN="nixos-fw"
              else
                CHAIN="INPUT"
              fi
            }

            open_port() {
              local port="''${1}"
              local proto="''${2:-tcp}"
              get_chain
              echo "==> Opening ''${proto} port ''${port} in firewall (''${CHAIN})..."
              if ! iptables -C "''${CHAIN}" -p "''${proto}" --dport "''${port}" -m comment --comment "nixos-expose" -j ACCEPT 2>/dev/null; then
                iptables -I "''${CHAIN}" 1 -p "''${proto}" --dport "''${port}" -m comment --comment "nixos-expose" -j ACCEPT
              fi
            }

            close_port() {
              local port="''${1}"
              local proto="''${2:-tcp}"
              get_chain
              echo "==> Closing ''${proto} port ''${port} in firewall (''${CHAIN})..."
              while iptables -C "''${CHAIN}" -p "''${proto}" --dport "''${port}" -m comment --comment "nixos-expose" -j ACCEPT 2>/dev/null; do
                iptables -D "''${CHAIN}" -p "''${proto}" --dport "''${port}" -m comment --comment "nixos-expose" -j ACCEPT
              done
            }

            close_port_and_socat() {
              local port="''${1}"
              local proto="''${2:-tcp}"
              close_port "''${port}" "''${proto}"
              local pids
              pids=$(pgrep -f "socat.*LISTEN:''${port}," || true)
              if [ -n "''${pids}" ]; then
                echo "==> Stopping socat forwarding on port ''${port}..."
                for pid in ''${pids}; do
                  kill "''${pid}" 2>/dev/null || true
                done
              fi
              echo "==> Done. Port ''${port} is closed."
            }

            list_rules() {
              get_chain
              echo "=== Active Temporary Firewall Rules (nixos-expose) ==="
              local rules
              rules=$(iptables -L "''${CHAIN}" -n --line-numbers 2>/dev/null | grep "nixos-expose" || true)
              if [ -n "''${rules}" ]; then
                echo "''${rules}"
              else
                echo "  (No temporary firewall rules active)"
              fi
              echo ""
              echo "=== Active Background Socat Forwards ==="
              local socats
              socats=$(pgrep -a -f "socat.*LISTEN:" 2>/dev/null || true)
              if [ -n "''${socats}" ]; then
                echo "''${socats}"
              else
                echo "  (No background socat forwards running)"
              fi
            }

            PROTO="tcp"
            DAEMON=0
            ARGS=()

            while [ "$#" -gt 0 ]; do
              case "$1" in
                -h|--help)
                  show_help
                  exit 0
                  ;;
                -u|--udp)
                  PROTO="udp"
                  shift
                  ;;
                -d|-b|--daemon|--background)
                  DAEMON=1
                  shift
                  ;;
                *)
                  ARGS+=("$1")
                  shift
                  ;;
              esac
            done

            if [ "''${#ARGS[@]}" -eq 0 ]; then
              show_help
              exit 1
            fi

            ACTION="''${ARGS[0]}"

            if [ "''${ACTION}" = "list" ] || [ "''${ACTION}" = "status" ]; then
              list_rules
              exit 0
            fi

            if [ "''${ACTION}" = "close" ] || [ "''${ACTION}" = "stop" ] || [ "''${ACTION}" = "remove" ]; then
              if [ "''${#ARGS[@]}" -lt 2 ]; then
                echo "Error: Please specify the port to close. Example: expose close 9090"
                exit 1
              fi
              close_port_and_socat "''${ARGS[1]}" "''${PROTO}"
              exit 0
            fi

            if [ "''${ACTION}" = "open" ]; then
              if [ "''${#ARGS[@]}" -lt 2 ]; then
                echo "Error: Please specify the port to open. Example: expose open 9090"
                exit 1
              fi
              ARGS=("''${ARGS[@]:1}")
            fi

            DO_FORWARD=0
            LOCAL_PORT=""
            TARGET_IP=""
            TARGET_PORT=""

            FIRST_ARG="''${ARGS[0]}"

            if [ "''${#ARGS[@]}" -ge 2 ] && [[ "''${FIRST_ARG}" =~ ^[0-9]+$ ]] && [[ "''${ARGS[1]}" =~ ^([^:]+):([0-9]+)$ ]]; then
              LOCAL_PORT="''${FIRST_ARG}"
              TARGET_IP="''${BASH_REMATCH[1]}"
              TARGET_PORT="''${BASH_REMATCH[2]}"
              DO_FORWARD=1
            elif [[ "''${FIRST_ARG}" =~ ^([0-9]+):([^:]+):([0-9]+)$ ]]; then
              LOCAL_PORT="''${BASH_REMATCH[1]}"
              TARGET_IP="''${BASH_REMATCH[2]}"
              TARGET_PORT="''${BASH_REMATCH[3]}"
              DO_FORWARD=1
            elif [[ "''${FIRST_ARG}" =~ ^([^:]+):([0-9]+)$ ]]; then
              TARGET_IP="''${BASH_REMATCH[1]}"
              TARGET_PORT="''${BASH_REMATCH[2]}"
              LOCAL_PORT="''${TARGET_PORT}"
              DO_FORWARD=1
            elif [[ "''${FIRST_ARG}" =~ ^([0-9]+)(/(tcp|udp))?$ ]]; then
              LOCAL_PORT="''${BASH_REMATCH[1]}"
              if [ -n "''${BASH_REMATCH[3]:-}" ]; then
                PROTO="''${BASH_REMATCH[3]}"
              fi
              DO_FORWARD=0
            else
              echo "Error: Unrecognized arguments: ''${ARGS[*]}"
              show_help
              exit 1
            fi

            open_port "''${LOCAL_PORT}" "''${PROTO}"

            mapfile -t IPS < <(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1)

            PROTO_UPPER=$(echo "''${PROTO}" | tr '[:lower:]' '[:upper:]')

            if [ "''${DO_FORWARD}" -eq 1 ]; then
              echo "================================================================"
              echo "  EXPOSING: ''${TARGET_IP}:''${TARGET_PORT} -> Local Port ''${LOCAL_PORT} (''${PROTO_UPPER})"
              echo "================================================================"
              echo "  Firewall port ''${LOCAL_PORT} opened."
              echo "  Accessible from your network via:"
              for ip in "''${IPS[@]}"; do
                if [ -n "''${ip}" ]; then
                  echo "    -> http://''${ip}:''${LOCAL_PORT}  (or ''${ip}:''${LOCAL_PORT})"
                fi
              done
              echo "    -> localhost:''${LOCAL_PORT}"
              echo "================================================================"

              if [ "''${DAEMON}" -eq 1 ]; then
                if [ "''${PROTO}" = "tcp" ]; then
                  socat "TCP-LISTEN:''${LOCAL_PORT},fork,reuseaddr" "TCP:''${TARGET_IP}:''${TARGET_PORT}" >/dev/null 2>&1 &
                else
                  socat "UDP-LISTEN:''${LOCAL_PORT},fork,reuseaddr" "UDP:''${TARGET_IP}:''${TARGET_PORT}" >/dev/null 2>&1 &
                fi
                SOCAT_PID=$!
                echo "==> Running in background (PID: ''${SOCAT_PID})."
                echo "==> To stop and close port later, run: expose close ''${LOCAL_PORT}"
              else
                cleanup() {
                  echo ""
                  echo "==> Stopping forward..."
                  close_port "''${LOCAL_PORT}" "''${PROTO}"
                  exit 0
                }
                trap cleanup INT TERM

                echo "==> Forwarding traffic... Press Ctrl+C to stop and close firewall."
                if [ "''${PROTO}" = "tcp" ]; then
                  socat "TCP-LISTEN:''${LOCAL_PORT},fork,reuseaddr" "TCP:''${TARGET_IP}:''${TARGET_PORT}"
                else
                  socat "UDP-LISTEN:''${LOCAL_PORT},fork,reuseaddr" "UDP:''${TARGET_IP}:''${TARGET_PORT}"
                fi
              fi
            else
              echo "================================================================"
              echo "  PORT ''${LOCAL_PORT}/''${PROTO_UPPER} OPENED IN FIREWALL"
              echo "================================================================"
              echo "  Accessible from your network via:"
              for ip in "''${IPS[@]}"; do
                if [ -n "''${ip}" ]; then
                  echo "    -> http://''${ip}:''${LOCAL_PORT}  (or ''${ip}:''${LOCAL_PORT})"
                fi
              done
              echo "================================================================"

              if [ "''${DAEMON}" -eq 1 ]; then
                echo "==> Firewall port ''${LOCAL_PORT} left open in background."
                echo "==> To close later, run: expose close ''${LOCAL_PORT}"
              else
                cleanup() {
                  echo ""
                  echo "==> Closing firewall port ''${LOCAL_PORT}..."
                  close_port "''${LOCAL_PORT}" "''${PROTO}"
                  exit 0
                }
                trap cleanup INT TERM

                echo "==> Port ''${LOCAL_PORT} is open. Press Ctrl+C to close and exit..."
                while true; do
                  sleep 3600
                done
              fi
            fi
    '';
  };
in
{
  environment.systemPackages = [
    expose
    pkgs.socat
  ];

  networking.firewall = {
    enable = true;

    # Open TCP ports
    allowedTCPPorts = [
      # 22       # SSH
      # 80       # HTTP
      # 443      # HTTPS
      # 3000     # Web / Node dev servers
      # 5173     # Vite dev server
      # 8000     # Dev servers (FastAPI/Django/Python)
      # 8080     # HTTP alt
      # 8384     # Syncthing Web UI
      # 22000    # Syncthing listening port
    ];

    # Open UDP ports
    allowedUDPPorts = [
      # 53       # DNS
      # 22000    # Syncthing listening port
      # 21027    # Syncthing discovery
    ];

    # Open TCP port ranges
    allowedTCPPortRanges = [
      # { from = 8000; to = 8010; }
    ];

    # Open UDP port ranges
    allowedUDPPortRanges = [
      # { from = 4000; to = 4007; }
    ];

    # Allow ping / ICMP echo requests
    allowPing = true;

    # Set to true to log dropped packets in dmesg/journalctl
    logRefusedConnections = false;
  };
}
