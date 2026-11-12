# Second computer: Intel i5-3210M / i5-3230M laptop (HDD)

The same desktop as the main machine: niri, waybar, the shell, terminals,
networking (NetworkManager, Tailscale, split DNS), the SSH toggle and the
`wifi-hotspot` command. The home-manager config is the shared
`nixos/modules/home/mod.nix`, so the look and the key bindings are identical.

The username, home directory and everything else shared comes from
`nixos/vars.nix`.

It is delivered as an **installer ISO**: it boots live, partitions `/dev/sda`
(LUKS2 + bcachefs) and installs the finished system from its own contents, with
no network. One password, set when you build, is the disk passphrase and the
password of both the user and root.

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
LAPTOP_PASSWORD='your password' nix build .#laptop-intel-i5 --impure -o result-installer
ls -lh result-installer/iso/
```

`--impure` is what lets Nix read `LAPTOP_PASSWORD`. Without the variable the
build stops with a message.

The plaintext password ends up in the ISO, because it has to format the LUKS
volume, and in the build host's /nix/store. The installed laptop only gets a
yescrypt hash of it. Treat the ISO and the USB stick like the password: delete
them after installing, and change the passphrase on the laptop if the ISO was
shared (`sudo cryptsetup luksChangeKey /dev/disk/by-partlabel/cryptroot`).

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

It asks you to type the disk path and installs; the passphrase is the one the ISO
was built with, so it asks nothing else. It refuses a disk that has mounted
filesystems, which is how the USB stick it booted from looks. The keyboard is
Brazilian ABNT2 in the live system and in the boot prompt. Reboot and remove the
stick.

## First boot

- The boot prompt asks for the LUKS passphrase: the build password.
- The user and root log in with the same password.
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

No password variable is needed here: with `LAPTOP_PASSWORD` unset the accounts keep
their current passwords.

## Files

- `configuration.nix` - what is installed and which shared modules are used
- `hardware.nix` - disk, LUKS2, bcachefs, boot, CPU/GPU, HDD tuning
- `installer.nix` - the installer ISO (`laptop-intel-i5`)
- `password.nix` - user and root password hash from `LAPTOP_PASSWORD`
- `install.sh` - the `install-laptop-i5` command that partitions and installs
