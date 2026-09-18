# Nightly encrypted backups to S3.
#
# Restic encrypts client-side, so the bucket never holds readable data and the
# repository password is the only thing standing between a leaked bucket and the
# contents. That password and the S3 credentials both come from sops.
#
# What is backed up is state, not data that can be rebuilt: Nextcloud's files
# and database dump, the Vaultwarden store, and Home Assistant's configuration
# and history. Jellyfin's library and the torrent directory are deliberately
# left out -- they are large and replaceable.
{ config, lib, ... }:
{
  services.restic.backups.homelab = {
    initialize = true;

    repositoryFile = config.sops.secrets."restic/repository".path;
    passwordFile = config.sops.secrets."restic/password".path;
    environmentFile = config.sops.secrets."restic/s3-env".path;

    paths = [
      "/var/lib/nextcloud/data"
      "/var/lib/bitwarden_rs"
      "/var/lib/hass"
      "/var/backup/postgresql"
    ];

    exclude = [
      "/var/lib/nextcloud/data/*/cache"
      "/var/lib/nextcloud/data/appdata_*/preview"
    ];

    timerConfig = {
      OnCalendar = "03:00";
      # Every other machine on the planet also backs up at 03:00; spread the
      # load on the bucket and avoid colliding with the Nextcloud cron.
      RandomizedDelaySec = "45min";
      Persistent = true;
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    # A consistent database snapshot has to exist before the files are read.
    backupPrepareCommand = ''
      ${config.services.postgresql.package}/bin/pg_dumpall \
        --file=/var/backup/postgresql/all.sql
    '';
  };

  systemd.services.restic-backups-homelab.serviceConfig = {
    MemoryMax = "1G";
    CPUWeight = 10; # the lowest weight in the stack: backups yield to everything
    IOWeight = 10;
    ReadWritePaths = [ "/var/backup/postgresql" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/backup/postgresql 0700 postgres postgres -"
  ];

  # pg_dumpall has to run as a user PostgreSQL trusts.
  systemd.services.restic-backups-homelab.serviceConfig.User = lib.mkForce "root";
}
