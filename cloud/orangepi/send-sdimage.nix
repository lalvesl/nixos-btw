# `nix run .#send-orangepi-sdimage`
#
# Writes the cross-compiled NixOS sd-image straight onto the Orange Pi 5's
# soldered eMMC over USB, using the RK3588 BootROM in maskrom mode. No SD card
# and no access to whatever is currently installed on the board are needed.
{
  pkgs,
  sdImage,
  imageName ? "orangepi-sd-image.img.zst",
}:
let
  # rkdeveloptool cannot talk to a bare maskrom device until a DDR-init blob is
  # running in SRAM. That blob is the "spl loader", and nixpkgs' rkbin only
  # ships the loose pieces, so assemble it here with Rockchip's own boot_merger.
  rk3588Loader = pkgs.runCommand "rk3588-spl-loader.bin" { } ''
    cp -r ${pkgs.rkbin.src} rkbin
    chmod -R u+w rkbin
    cd rkbin
    ./tools/boot_merger RKBOOT/RK3588MINIALL.ini
    cp rk3588_spl_loader_*.bin $out
  '';
in
pkgs.writeShellApplication {
  name = "send-orangepi-sdimage";

  runtimeInputs = with pkgs; [
    rkdeveloptool
    zstd
    coreutils
  ];

  text = ''
    set -euo pipefail

    # Run this WITHOUT sudo. `sudo nix run` would build as root, using root's
    # nix config and cache instead of yours. Only the rkdeveloptool calls need
    # privileges, so escalate just those. If we are already root (someone used
    # sudo anyway), skip sudo entirely so nothing breaks.
    if [ "$(id -u)" -eq 0 ]; then
      run_priv() { "$@"; }
    else
      run_priv() { sudo "$@"; }
    fi

    LOADER=${rk3588Loader}
    COMPRESSED=${sdImage}/sd-image/${imageName}

    WORKDIR="$(mktemp -d "''${TMPDIR:-/tmp}/orangepi-flash.XXXXXX")"
    cleanup() {
      if [ "''${KEEP_IMAGE:-0}" = "1" ]; then
        echo "Keeping the decompressed image at $WORKDIR/orangepi.img"
      else
        rm -rf "$WORKDIR"
      fi
    }
    trap cleanup EXIT

    cat <<'BANNER'
    ===============================================================
     Orange Pi 5 -- flash NixOS to the soldered eMMC over USB
    ===============================================================

    Run this WITHOUT sudo. It asks for the password itself, only for
    the steps that actually need it.

    Put the board into maskrom mode before continuing.

      1. Unplug everything. The board must be completely unpowered.
      2. Press and hold the MASKROM button.
      3. While still holding it, plug the USB-C cable into the DATA
         port and into this computer.
      4. Keep holding for about three seconds, then let go.

    Which connector is which, looking at the board with the 40-pin
    GPIO header along the TOP edge:

        +-----------------------------------------------+
        |  o o o o o o o o o o o o o o o o o o o o      |   <- GPIO header
        |                                               |
        |                                               |
        +--[ POWER ]--[ DATA ]--------------------------+
           bottom-left    bottom-left
             corner         centre

      * BOTTOM-LEFT CORNER  = POWER ONLY. 5V input. It cannot flash.
      * BOTTOM-LEFT CENTRE  = DATA (USB OTG). This is the one that
                              talks to the BootROM. Use this one.

    Plugging the cable into the DATA port also powers the board, so
    leave the POWER port empty for the whole procedure. If you use
    the POWER port by mistake the board just boots normally and
    `rkdeveloptool ld` will find nothing.

    WARNING: this ERASES the eMMC completely, including any existing
    Debian install, its partition table and its bootloader. There is
    no undo. To keep a backup first, run:

        sudo rkdeveloptool rl 0 <sectors> emmc-backup.img

    BANNER

    read -r -p "Board in maskrom mode and DATA cable connected? [y/N] " answer
    case "$answer" in
      [yY] | [yY][eE][sS]) ;;
      *)
        echo "Aborted. Nothing was written."
        exit 1
        ;;
    esac

    if [ "$(id -u)" -ne 0 ]; then
      echo
      echo "==> Asking for sudo once, up front"
      echo "    Only rkdeveloptool needs it. The credential is cached so the"
      echo "    write is not interrupted by a prompt half way through."
      sudo -v
    fi

    echo
    echo "==> Looking for a device in maskrom mode"
    if ! run_priv rkdeveloptool ld | grep -qi maskrom; then
      echo "No maskrom device found." >&2
      echo "Unplug, hold MASKROM, plug the DATA port back in, and retry." >&2
      run_priv rkdeveloptool ld >&2 || true
      exit 1
    fi
    run_priv rkdeveloptool ld

    echo
    echo "==> Uploading the DDR init loader to SRAM"
    run_priv rkdeveloptool db "$LOADER"

    echo
    echo "==> Decompressing the sd-image"
    echo "    source: $COMPRESSED"
    zstd -d -f -o "$WORKDIR/orangepi.img" "$COMPRESSED"

    echo
    echo "==> Writing to eMMC from sector 0"
    echo "    This moves about 3 GB over USB and takes 10-20 minutes."
    echo "    Progress is not reported. Do not unplug the board."
    run_priv rkdeveloptool wl 0 "$WORKDIR/orangepi.img"

    echo
    echo "==> Rebooting the board"
    run_priv rkdeveloptool rd

    cat <<'DONE'

    Done. The image carries its own U-Boot at the offsets the BootROM
    looks for, so the eMMC is bootable as-is. The root partition grows
    to fill the eMMC on the first boot.

    Next: find the board's address on the network, put it in
    cloud/colmena.nix, and deploy further changes with

        colmena apply --on orangepi

    DONE
  '';
}
