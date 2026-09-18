# Home-lab service stack for the Orange Pi 5.
#
# A word on what this board is: 16 GB of RAM, but eight Cortex-A76/A55 cores on
# a vendor 6.1 kernel, storage on eMMC or USB, and one of these services
# (Valheim) already running x86_64 code under box64 emulation. Nextcloud with
# Elasticsearch, Jellyfin, Home Assistant and a CI runner alongside that is well
# past what the hardware comfortably carries. Every heavy unit here therefore
# carries an explicit MemoryMax and a CPUWeight, so that when something has to
# give it is the batch work (CI, backups, indexing) rather than the interactive
# services.
#
# Imported by colmena only. The SD image stays minimal.
{
  imports = [
    ./proxy.nix
    ./dns.nix
    ./nextcloud.nix
    ./media.nix
    ./iot.nix
    ./dev.nix
    ./backup.nix
    ./firewall.nix
    ./resources.nix
  ];
}
