# "gamebox": a distrobox-like sandbox for gaming (Steam/Lutris/Wine/Proton)
# that gets GPU + audio + display, but *no* access to host files.
#
# Unlike distrobox (which deliberately bind-mounts the host home/root for
# seamless integration), this container only ever sees:
#   - the GPU device (nvidia CDI + /dev/dri)
#   - the PipeWire/Pulse sockets
#   - the Wayland/X11 display sockets
#   - a dedicated podman volume (gamebox-home) for its own state
# There is no bind mount of $HOME, /, /etc, or the docker/podman socket.
{ pkgs, ... }:
let
  gameboxImage = import ./gamebox-image.nix { inherit pkgs; };

  gamebox = pkgs.writeShellApplication {
    name = "gamebox";
    runtimeInputs = [ pkgs.podman ];
    text = ''
      IMAGE_NAME="gamebox:latest"
      CONTAINER_NAME="gamebox"
      RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

      ensure_image() {
        if ! podman image exists "$IMAGE_NAME"; then
          echo "==> Loading gamebox image into podman (first run, this takes a while)..."
          podman load -i ${gameboxImage}
        fi
      }

      ensure_container() {
        if podman container exists "$CONTAINER_NAME"; then
          if [ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
            podman start "$CONTAINER_NAME" >/dev/null
          fi
          return
        fi

        local -a devices=()
        local -a mounts=()

        # GPU: nvidia via CDI (hardware.nvidia-container-toolkit) + generic DRI render node
        if [ -e /etc/cdi/nvidia.yaml ]; then
          devices+=(--device nvidia.com/gpu=all)
        fi
        if [ -d /dev/dri ]; then
          devices+=(--device /dev/dri)
        fi

        # Audio: PipeWire native + pulse-compat sockets
        if [ -S "$RUNTIME_DIR/pipewire-0" ]; then
          mounts+=(-v "$RUNTIME_DIR/pipewire-0:$RUNTIME_DIR/pipewire-0")
        fi
        if [ -d "$RUNTIME_DIR/pulse" ]; then
          mounts+=(-v "$RUNTIME_DIR/pulse:$RUNTIME_DIR/pulse")
        fi

        # Display: Wayland socket + X11/Xwayland socket dir
        if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -S "$RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
          mounts+=(-v "$RUNTIME_DIR/$WAYLAND_DISPLAY:$RUNTIME_DIR/$WAYLAND_DISPLAY")
        fi
        if [ -d /tmp/.X11-unix ]; then
          mounts+=(-v /tmp/.X11-unix:/tmp/.X11-unix:ro)
        fi
        if [ -n "''${XAUTHORITY:-}" ] && [ -f "''${XAUTHORITY:-}" ]; then
          mounts+=(-v "$XAUTHORITY:/home/gamer/.Xauthority:ro")
        fi

        echo "==> Creating gamebox container..."
        podman run -d \
          --name "$CONTAINER_NAME" \
          --userns=keep-id \
          --hostname gamebox \
          --security-opt label=disable \
          "''${devices[@]}" \
          "''${mounts[@]}" \
          -e "XDG_RUNTIME_DIR=$RUNTIME_DIR" \
          -e "WAYLAND_DISPLAY=''${WAYLAND_DISPLAY:-}" \
          -e "DISPLAY=''${DISPLAY:-}" \
          -e "XAUTHORITY=/home/gamer/.Xauthority" \
          -e "PULSE_SERVER=$RUNTIME_DIR/pulse/native" \
          -v gamebox-home:/home/gamer \
          "$IMAGE_NAME" \
          sleep infinity >/dev/null
      }

      ensure_image
      ensure_container

      case "''${1:-shell}" in
        steam)  exec podman exec -it "$CONTAINER_NAME" steam ;;
        lutris) exec podman exec -it "$CONTAINER_NAME" lutris ;;
        shell)  exec podman exec -it "$CONTAINER_NAME" bash ;;
        stop)   exec podman stop "$CONTAINER_NAME" ;;
        reset)
          podman rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
          podman volume rm gamebox-home >/dev/null 2>&1 || true
          echo "gamebox container and data removed."
          ;;
        put)
          if [ $# -lt 2 ]; then
            echo "usage: gamebox put <host-file> [dest-path-in-container]" >&2
            exit 1
          fi
          src="$2"
          dest="''${3:-/home/gamer/$(basename "$src")}"
          podman cp "$src" "$CONTAINER_NAME:$dest"
          echo "==> copied $src -> gamebox:$dest"
          ;;
        get)
          if [ $# -lt 3 ]; then
            echo "usage: gamebox get <path-in-container> <host-dest>" >&2
            exit 1
          fi
          podman cp "$CONTAINER_NAME:$2" "$3"
          echo "==> copied gamebox:$2 -> $3"
          ;;
        *) exec podman exec -it "$CONTAINER_NAME" "$@" ;;
      esac
    '';
  };

  gameboxSteamDesktop = pkgs.makeDesktopItem {
    name = "gamebox-steam";
    desktopName = "Steam (gamebox)";
    comment = "Steam sandboxed in gamebox — no host filesystem access";
    exec = "${gamebox}/bin/gamebox steam";
    icon = "steam";
    categories = [ "Game" ];
  };

  gameboxLutrisDesktop = pkgs.makeDesktopItem {
    name = "gamebox-lutris";
    desktopName = "Lutris (gamebox)";
    comment = "Lutris sandboxed in gamebox — no host filesystem access";
    exec = "${gamebox}/bin/gamebox lutris";
    icon = "lutris";
    categories = [ "Game" ];
  };
in
{
  environment.systemPackages = [
    gamebox
    gameboxSteamDesktop
    gameboxLutrisDesktop
  ];
}
