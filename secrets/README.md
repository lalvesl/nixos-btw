# Secrets

Secrets are encrypted with [sops](https://github.com/getsops/sops) + age.
`sops-nix` decrypts them at activation time into `/run/secrets/<name>`, which is
ramfs -- it can never be paged out to disk. Cleartext never reaches the
`/nix/store`.

The encrypted `.yaml` files are **gitignored**: they are not committed, not
pushed, and not part of the flake source. Because a flake can only read files
git tracks, the modules reference them by absolute path as strings, with
`sops.validateSopsFiles = false`. Two consequences worth knowing:

- **There is no history and no remote copy.** Git will not bring these files
  back. Back up `secrets/*.yaml` wherever you back up the admin key -- losing
  the file loses the secrets just as surely as losing the key does.
- **The path is hardcoded.** Move this repository and `secretsDir` in
  `nixos/modules/secrets.nix` and `keyFile` in `cloud/colmena.nix` must move
  with it.

Everything below assumes you are inside `nix develop`, which provides `sops`,
`age`, `ssh-to-age`, `mkpasswd` and `colmena`, and points `SOPS_AGE_KEY_FILE` at
the admin key.

## Layout

| File (gitignored) | Environment | Decryptable by | Reaches the host via |
| --- | --- | --- | --- |
| `secrets/desktop.yaml` | this machine (`lalvesl-nix`) | admin + desktop | read in place at activation |
| `secrets/cloud/orangepi.yaml` | the Orange Pi, via colmena | admin + orangepi | `deployment.keys` -> `/var/lib/sops/` |
| `secrets/wallet.yaml` | wallet ISO (not in use yet) | admin | -- |

`.sops.yaml` at the repo root is what binds each path to its key set. Separation
between environments is cryptographic: a compromised orangepi cannot decrypt the
desktop's secrets.

## The admin key

`~/.config/sops/age/keys.txt`. It is in every file, so it is the one thing that
must be backed up somewhere offline. Lose it with no backup and every secret in
this repo is unrecoverable.

It is never committed, and nothing on any machine reads it -- hosts decrypt with
their own keys. It exists so *you* can edit.

## Everyday use

Edit a file (opens decrypted in `$EDITOR`, re-encrypts on save):

    sops secrets/cloud/orangepi.yaml

Read a single value without opening an editor:

    sops -d --extract '["valheim"]["password"]' secrets/cloud/orangepi.yaml

Set a password without it touching shell history or the screen:

    ./secrets/set-password.sh secrets/cloud/orangepi.yaml users/lalvesl/hashed-password

## Consuming a secret from Nix

Declare it, then reference it **by path**. Never `builtins.readFile` a secret and
never interpolate one into a Nix string -- both copy the cleartext into the
world-readable store.

    sops.secrets."tokens/some-service" = {
      owner = "some-user";
      mode = "0400";
      restartUnits = [ "some.service" ];
    };

    systemd.services.some.serviceConfig.EnvironmentFile =
      config.sops.secrets."tokens/some-service".path;

For a service that wants an env file with several variables, use
`sops.templates` instead of hand-assembling one.

## Adding a new host

A host's age identity is derived from its SSH host key, which only exists after
its first boot. So:

1. Boot it with a bootstrap module (cleartext initial password, no sops).
2. `./secrets/add-host-key.sh <alias> <ip>` and follow the three steps it prints:
   add the key to `.sops.yaml`, enable it in the relevant `creation_rule`, then
   `sops updatekeys <file>`.
3. Deploy again. From now on the host decrypts its own secrets.

`sops updatekeys` is not optional -- editing `.sops.yaml` alone changes nothing
about files that are already encrypted.

## Orange Pi bootstrap, concretely

    # 1. flash and boot the SD image, then find the board on the network
    nix run .#send-orangepi-sdimage

    # 2. once it is up (user lalvesl / root, password "changeme")
    nix develop
    ./secrets/add-host-key.sh orangepi <board-ip>
    # ... apply the three steps it prints ...

    # 3. set the real passwords
    ./secrets/set-password.sh secrets/cloud/orangepi.yaml users/lalvesl/hashed-password
    ./secrets/set-password.sh secrets/cloud/orangepi.yaml users/root/hashed-password

    # 4. deploy; this is what replaces bootstrap.nix with secrets.nix
    colmena apply --on orangepi

Update `deployment.targetHost` in `cloud/colmena.nix` with the board's real
address first.

## Rotating and revoking

Rotate a value: `sops secrets/<file>.yaml`, change it, save. Any
`restartUnits` you declared restarts on the next activation.

Revoke a host: remove its key from `.sops.yaml`, run `sops updatekeys` on the
affected files, then rotate the values themselves. Removing the key only stops
*future* versions from being readable -- anything that host already read, and
any older commit, stays readable to whoever holds that key.
