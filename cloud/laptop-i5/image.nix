# Final disk image for the i5 laptop: write it to the HDD and boot.
#
#   LAPTOP_PASSWORD='...' nix build .#laptop-intel-i5 --impure
#
# The partitions are made on the host, then a VM (with the same kernel and the
# bcachefs module as the laptop) formats LUKS2 with the password, puts a bcachefs
# inside, installs the system and the bootloader, and closes everything again.
# Layout (same as the labels in hardware.nix):
#   1  1 MiB   BIOS boot
#   2  1 GiB   ESP, FAT32, /boot
#   3  rest    LUKS2 "cryptroot" with a bcachefs inside, /
#
# LAPTOP_DISK_SIZE (optional, e.g. 465G) makes the image that big, so it fills
# the HDD exactly. Unset, it is sized to the system plus some room, and writing
# it is much faster; the rest of the disk stays unused until the partition, the
# LUKS mapping and the bcachefs are grown by hand (see README.md).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  password = builtins.getEnv "LAPTOP_PASSWORD";
  diskSize = builtins.getEnv "LAPTOP_DISK_SIZE";

  toplevel = config.system.build.toplevel;
  closureInfo = pkgs.closureInfo { rootPaths = [ toplevel ]; };

  # Same kernel as the laptop, plus its bcachefs module, so the build VM can
  # open LUKS and mount the filesystem exactly like the real boot will.
  vmTools = pkgs.vmTools.override {
    kernel = config.boot.kernelPackages.kernel;
    kernelModules = config.system.modulesTree;
  };

  hostTools = with pkgs; [
    coreutils
    gptfdisk
  ];

  vmTools' = with pkgs; [
    bcachefs-tools
    coreutils
    cryptsetup
    dosfstools
    gnugrep
    gnused
    kmod
    nix
    nixos-install-tools
    util-linux
  ];
in
{
  system.build.diskImage = vmTools.runInLinuxVM (
    pkgs.runCommand "lalvesl-i5-image"
      {
        # Read inside the VM; the plaintext never reaches the image.
        LAPTOP_PASSWORD = password;
        memSize = 3072;

        preVM = ''
          export PATH=${lib.makeBinPath hostTools}:$PATH
          mkdir -p $out

          ${
            if diskSize != "" then
              ''
                size=${diskSize}
              ''
            else
              ''
                # The system, plus 15 % for bcachefs, plus the 1 GiB ESP, the
                # LUKS header and some room to work in.
                used=$(xargs -a ${closureInfo}/store-paths du -sbc | tail -n 1 | cut -f1)
                size=$(( (used * 115 / 100 + 3 * 1024 * 1024 * 1024) / 1048576 + 1 ))M
              ''
          }
          diskImage=nixos.raw
          truncate -s "$size" $diskImage
          echo "Disk image size: $size"

          sgdisk \
            --new=1:0:+1M   --typecode=1:ef02 --change-name=1:bios \
            --new=2:0:+1G   --typecode=2:ef00 --change-name=2:ESP \
            --new=3:0:0     --typecode=3:8309 --change-name=3:cryptroot \
            $diskImage
        '';

        postVM = ''
          mv $diskImage $out/lalvesl-i5.img
        '';
      }
      ''
        export PATH=${lib.makeBinPath vmTools'}:$PATH

        # Kernel modules for LUKS, the filesystems and the crypto they use. The
        # kernel itself falls back to /run/modprobe for any algorithm it asks for.
        for m in dm_crypt xts aesni_intel aes_generic cryptd bcachefs vfat nls_cp437 nls_iso8859_1; do
          /run/modprobe "$m" || echo "note: module $m not loaded"
        done

        printf '%s' "$LAPTOP_PASSWORD" > /tmp/luks-key
        chmod 0400 /tmp/luks-key

        # There is no udev in this VM: tell libdevmapper not to wait for it, and
        # skip the lock directory under /run.
        export DM_DISABLE_UDEV=1

        cryptsetup --disable-locks luksFormat --type luks2 --label cryptroot \
          --batch-mode --key-file /tmp/luks-key /dev/vda3
        cryptsetup --disable-locks open --key-file /tmp/luks-key /dev/vda3 cryptroot
        rm -f /tmp/luks-key

        # zstd: the HDD is far slower than the two cores compressing in front of it.
        mkfs.bcachefs --compression=zstd --block_size=4096 --label nixos /dev/mapper/cryptroot
        mkfs.vfat -F 32 -n ESP /dev/vda2

        mkdir -p /mnt
        bcachefs mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount -t vfat /dev/vda2 /mnt/boot

        # Give nixos-install a Nix database that knows the closure.
        export HOME=$TMPDIR
        export NIX_STATE_DIR=$TMPDIR/state
        nix-store --load-db < ${closureInfo}/registration

        nixos-install --root /mnt --no-bootloader --no-root-passwd \
          --system ${toplevel} --no-channel-copy --substituters ""

        # grub.device is /dev/sda on the laptop; here that disk is /dev/vda.
        ln -s /dev/vda /dev/sda
        NIXOS_INSTALL_BOOTLOADER=1 nixos-enter --root /mnt -- \
          /nix/var/nix/profiles/system/bin/switch-to-configuration boot

        sync
        umount /mnt/boot
        umount /mnt
        cryptsetup --disable-locks close cryptroot
      ''
  );

  assertions = [
    {
      assertion = password != "";
      message = "Set the password and build with --impure: LAPTOP_PASSWORD=... nix build .#laptop-intel-i5 --impure";
    }
  ];
}
