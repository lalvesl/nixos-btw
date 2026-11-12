# Second computer: Intel i5-3210M / i5-3230M laptop (HDD)

The same desktop as the main machine: niri, waybar, the shell, terminals,
networking (NetworkManager, Tailscale, split DNS), the SSH toggle and the
`wifi-hotspot` command. The home-manager config is the shared
`nixos/modules/home/mod.nix`, so the look and the key bindings are identical.

The username, home directory and everything else shared comes from
`nixos/vars.nix`.

It is delivered as an **installer ISO**: it boots live, partitions `/dev/sda`
(LUKS2 + bcachefs) and installs the finished system from its own contents, with
no network. The disk is encrypted with a passphrase chosen at install time, so
there is no prebuilt disk image.

## What differs from the main machine

| Main machine                             | This laptop                                  |
| ---------------------------------------- | -------------------------------------------- |
| NVIDIA GTX 1050 + PRIME                  | Intel HD 4000 (`modesetting`, VA-API)        |
| niri fixed monitors + NVIDIA render node | niri picks the outputs (`hasNvidia = false`) |
| LUKS + btrfs on NVMe, systemd-boot       | LUKS2 + bcachefs on HDD, GRUB on BIOS + UEFI |
| sops secrets                             | none (no key on this machine)                |
| Steam, gamebox, MATLAB, KVM sandbox      | left out                                     |
| Docker, libvirt, Flatpak                 | left out                                     |
| IDE/editor set, ai-memory, Claude Code   | CLI editors and tools only                   |

## Disk layout (`/dev/sda`)

| # | Size    | Content                                       |
| - | ------- | --------------------------------------------- |
| 1 | 1 MiB   | BIOS boot (GRUB on a GPT disk, legacy BIOS)   |
| 2 | 1 GiB   | ESP, FAT32, `/boot` (kernels; not encrypted)  |
| 3 | rest    | LUKS2 `cryptroot` with a bcachefs inside, `/` |

The root takes whatever is left, so the size follows the HDD. Both boot partitions
are found by partition label, so only GRUB names the disk (`sda`, in
`hardware.nix`). The bcachefs is formatted with zstd compression.

bcachefs is an out-of-tree kernel module on this kernel (the in-tree one was
removed), built against the kernel the system uses. Treat the filesystem as an
experiment: keep what matters copied somewhere else.

## Build

```sh
nix build .#laptop-i5-installer -o result-installer
ls -lh result-installer/iso/
```

## Install

Write the ISO to a USB stick (check the device name first, `dd` overwrites the
whole disk), boot the laptop from it, then:

```sh
lsblk -o NAME,SIZE,MODEL
sudo dd if=result-installer/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

On the laptop, in the live system:

```sh
sudo install-laptop-i5          # defaults to /dev/sda
```

It asks you to type the disk path, then for the LUKS passphrase (twice), and
installs. The keyboard is Brazilian ABNT2 in the live system and in the boot
prompt, so the passphrase types the same both times. Reboot and remove the stick.

## First boot

- The boot prompt asks for the LUKS passphrase.
- The user's first password is `changeme` (`cloud/laptop-i5/configuration.nix`).
  Change it with `passwd`.
- Tailscale has to be logged in once: `sudo tailscale up`.
- SSH is off. To turn it on set `enable = true;` in `nixos/modules/ssh.nix` and
  rebuild.
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
- `hardware.nix` - disk, LUKS2, bcachefs, boot, CPU/GPU, HDD tuning
- `installer.nix` - the installer ISO (`laptop-i5-installer`)
- `install.sh` - the `install-laptop-i5` command that partitions and installs
