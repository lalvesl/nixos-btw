# Second computer: Intel i5-3210M / i5-3230M laptop (HDD)

The same desktop as the main machine: niri, waybar, the shell, terminals,
networking (NetworkManager, Tailscale, split DNS), the SSH toggle and the
`wifi-hotspot` command. The home-manager config is the shared
`nixos/modules/home/mod.nix`, so the look and the key bindings are identical.

The username, home directory and everything else shared comes from
`nixos/vars.nix`.

It is delivered as a **disk image** to write straight onto the HDD: GPT, LUKS2,
bcachefs, GRUB for legacy BIOS and UEFI. One password, set when you build, is the
disk passphrase and the password of both the user and root.

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

## Disk layout

| # | Size  | Content                                        |
| - | ----- | ---------------------------------------------- |
| 1 | 1 MiB | BIOS boot (GRUB on a GPT disk, legacy BIOS)    |
| 2 | 1 GiB | ESP, FAT32, `/boot` (kernels; not encrypted)   |
| 3 | rest  | LUKS2 `cryptroot` with a bcachefs inside, `/`  |

The root is found by partition label, so only GRUB names the disk (`/dev/sda`,
in `hardware.nix`). The bcachefs uses zstd compression. The LUKS2 key derivation
is argon2id and uses about 1 GiB of RAM while unlocking, so the laptop needs
more than 2 GiB of RAM.

bcachefs is an out-of-tree kernel module on this kernel (the in-tree one was
removed), built against the kernel the system uses. Treat the filesystem as an
experiment: keep what matters copied somewhere else.

## Build

```sh
LAPTOP_PASSWORD='your password' LAPTOP_DISK_SIZE=465G \
  nix build .#laptop-intel-i5 --impure
ls -lh result/        # lalvesl-i5.img
```

- `--impure` is what lets Nix read the variables. Without `LAPTOP_PASSWORD` the
  build stops with a message.
- `LAPTOP_DISK_SIZE` is optional. Set it to a little under the HDD size (a
  "500 GB" disk is about 465 GiB; `lsblk -b` on the laptop shows the exact
  bytes) so the image fills the disk exactly. Unset, the image is only as big as
  the system needs (about 14 GiB) and writing it takes minutes, but the rest of
  the HDD stays unused (see "Using the rest of the disk").

The plaintext password is read by the build and is in the build host's
`/nix/store` (inside the derivation). The image holds only the LUKS2 key slot and
a yescrypt hash of it. Delete the build result and change the password
(`passwd`, and `sudo cryptsetup luksChangeKey /dev/disk/by-partlabel/cryptroot`)
if the host's store is shared.

## Write it to the HDD

Check the device name first; `dd` overwrites the whole disk. Do not use
`conv=sparse`: it skips the empty parts, and old data on the HDD would stay there.

```sh
lsblk -o NAME,SIZE,MODEL,TRAN
sudo dd if=result/lalvesl-i5.img of=/dev/sdX bs=4M status=progress conv=fsync
```

With the HDD in a USB adapter this is done from the main machine. Otherwise
boot the laptop from any live system with the image on a USB stick and `dd` it
onto the internal disk.

## First boot

- The boot prompt asks for the LUKS passphrase: the build password.
- The user and root log in with the same password.
- Tailscale has to be logged in once: `sudo tailscale up`.
- SSH is off. To turn it on set `enable = true;` in `nixos/modules/ssh.nix` and
  rebuild.
- Wi-Fi: this laptop has an Atheros card. The in-kernel `ath9k` driver needs no
  firmware file, and newer Atheros/Qualcomm chips and the card's Bluetooth use
  `linux-firmware`, which is already enabled. Nothing to configure.

## Using the rest of the disk

Only needed when the image was built without `LAPTOP_DISK_SIZE`. These steps have
not been run on a real disk; do them with the data backed up.

```sh
sudo nix shell nixpkgs#cloud-utils -c growpart /dev/sda 3   # grow the partition
sudo cryptsetup resize cryptroot                            # grow the LUKS mapping
sudo bcachefs device resize /dev/mapper/cryptroot           # grow the filesystem
```

## Rebuilding on the laptop

```sh
git clone <repo> ~/super_balas/nixos-btw
cd ~/super_balas/nixos-btw
sudo nixos-rebuild switch --flake .#laptop-i5
```

No password variable is needed here: with `LAPTOP_PASSWORD` unset the accounts keep
their current passwords.

## Installer ISO (alternative)

`nix build .#laptop-intel-i5-installer --impure` (same `LAPTOP_PASSWORD`) builds a
live ISO instead. Boot it on the laptop and run `sudo install-laptop-i5`: it
partitions `/dev/sda`, creates the LUKS2 volume and the bcachefs, and installs
offline. It refuses a disk that has mounted filesystems, which is how the USB
stick it booted from looks. Unlike the image, the plaintext password is inside
this ISO.

## Files

- `configuration.nix` - what is installed and which shared modules are used
- `hardware.nix` - disk, LUKS2, bcachefs, boot, CPU/GPU, HDD tuning
- `password.nix` - user and root password hash from `LAPTOP_PASSWORD`
- `image.nix` - the disk image (`laptop-intel-i5`), built in a VM
- `installer.nix`, `install.sh` - the installer ISO (`laptop-intel-i5-installer`)
