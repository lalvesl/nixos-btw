# install-laptop-i5 [disk]
#
# Wipes the disk (default /dev/sda), lays it out for the i5 laptop and installs
# the system that is already inside this ISO. No network is needed.
#
#   1  1 MiB   BIOS boot  (GRUB on a GPT disk, legacy BIOS)
#   2  1 GiB   ESP        (FAT32, /boot)
#   3  rest    LUKS2      (bcachefs inside, /)
#
# $SYSTEM is the store path of the system to install (set by installer.nix).

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

disk=${1:-/dev/sda}

if [ ! -b "$disk" ]; then
  echo "$disk is not a block device" >&2
  exit 1
fi

# nvme0n1 and mmcblk0 name their partitions p1, p2...; sda names them sda1.
part() {
  case "$disk" in
    *[0-9]) echo "${disk}p$1" ;;
    *) echo "${disk}$1" ;;
  esac
}

lsblk -o NAME,SIZE,TYPE,MODEL,FSTYPE "$disk"
echo
echo "This ERASES everything on $disk and installs the laptop system."
read -r -p "Type the disk path ($disk) to continue: " answer
if [ "$answer" != "$disk" ]; then
  echo "Aborted."
  exit 1
fi

# A previous run may have left things open.
umount -R /mnt 2>/dev/null || true
cryptsetup close cryptroot 2>/dev/null || true

wipefs --all --force "$disk"
sgdisk --zap-all "$disk"
sgdisk --new=1:0:+1M --typecode=1:ef02 --change-name=1:bios "$disk"
sgdisk --new=2:0:+1G --typecode=2:ef00 --change-name=2:ESP "$disk"
sgdisk --new=3:0:0 --typecode=3:8309 --change-name=3:cryptroot "$disk"
partprobe "$disk"
udevadm settle

echo
echo "Choose the disk passphrase. It is asked on every boot, and typed on the"
echo "Brazilian ABNT2 layout, the same one the boot prompt uses."
cryptsetup luksFormat --type luks2 --label cryptroot "$(part 3)"
cryptsetup open "$(part 3)" cryptroot

# zstd: the HDD is far slower than the two cores compressing in front of it.
mkfs.bcachefs --compression=zstd --label nixos /dev/mapper/cryptroot
mkfs.vfat -F 32 -n ESP "$(part 2)"

mount -t bcachefs /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount "$(part 2)" /mnt/boot

# The account starts with the password written in configuration.nix.
nixos-install --system "$SYSTEM" --no-root-passwd

echo
echo "Done. Remove the USB stick and reboot. The first password of the user is"
echo "the one in cloud/laptop-i5/configuration.nix; change it with passwd."
