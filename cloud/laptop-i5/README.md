# Second computer: Intel i5-3210M / i5-3230M laptop (HDD)

A raw disk image of the same desktop as the main machine: niri, waybar, the
shell, terminals, networking (NetworkManager, Tailscale, split DNS), the SSH
toggle and the `wifi-hotspot` command. The home-manager config is the shared
`nixos/modules/home/mod.nix`, so the look and the key bindings are identical.

The username, home directory and everything else shared comes from
`nixos/vars.nix`.

## What differs from the main machine

| Main machine                           | This laptop                                |
| -------------------------------------- | ------------------------------------------ |
| NVIDIA GTX 1050 + PRIME                | Intel HD 4000 (`modesetting`, VA-API)      |
| niri fixed monitors + NVIDIA render node | niri picks the outputs (`hasNvidia = false`) |
| LUKS + btrfs on NVMe, systemd-boot     | ext4 on HDD, GRUB on BIOS **and** UEFI     |
| sops secrets                           | none (no key on this machine)              |
| Steam, gamebox, MATLAB, KVM sandbox    | left out                                   |
| Docker, libvirt, Flatpak               | left out                                   |
| IDE/editor set, ai-memory, Claude Code | CLI editors and tools only                 |

The first-boot password of the user is `changeme`. Change it with `passwd`.

## Build

```sh
nix build .#laptop-i5-image
ls -lh result/        # nixos.img
```

The build boots a small VM to install the bootloader, so it needs `/dev/kvm`.

## Write it to the HDD

Check the device name first; `dd` overwrites the whole disk.

```sh
lsblk -o NAME,SIZE,MODEL
sudo dd if=result/nixos.img of=/dev/sdX bs=4M status=progress conv=fsync
```

With the HDD in an enclosure or a USB adapter this is done from the main
machine. Otherwise write the image to a USB stick, boot the laptop from it and
`dd` from there onto the internal disk.

## First boot

- The image is small; the first boot grows the root partition and the
  filesystem to fill the whole disk, so it takes a little longer.
- The disk has a BIOS boot partition and an EFI partition, so it starts the same
  way on legacy BIOS and on UEFI. If the firmware lists two entries, either works.
- Tailscale has to be logged in once: `sudo tailscale up`.
- SSH is off. To turn it on set `enable = true;` in `nixos/modules/ssh.nix` and
  rebuild (this machine: `sudo nixos-rebuild switch --flake .#laptop-i5`).
- Wi-Fi: this laptop has an Atheros card. The in-kernel `ath9k` driver needs no
  firmware file, and newer Atheros/Qualcomm chips and the card's Bluetooth use
  `linux-firmware`, which is already enabled. Nothing to configure.

## Rebuilding on the laptop

```sh
git clone <repo> ~/super_balas/nixos-btw
cd ~/super_balas/nixos-btw
sudo nixos-rebuild switch --flake .#laptop-i5
```

## Files

- `configuration.nix` - what is installed and which shared modules are used
- `hardware.nix` - disk, boot, CPU/GPU, HDD tuning
- `image.nix` - the raw disk image (`system.build.diskImage`)
