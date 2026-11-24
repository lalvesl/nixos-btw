# Guest side of `sbx`: the command every SSH session runs. Enters the project's
# dev shell, built once and cached on the guest disk by a hash of the files
# that define it, then hands over to zsh (or to the command given).
#
# usage: sbx-enter <subdir> [reload] [-- cmd...]

subdir=${1:-}
shift || true
reload=
if [ "${1:-}" = reload ]; then
  reload=1
  shift
fi
[ "${1:-}" = -- ] && shift

cd "/work/$subdir" 2>/dev/null || cd /work

cache=/var/cache/sbx/devshell
mkdir -p "$cache"

kind=
if [ -f /work/flake.nix ]; then
  kind=flake
  key=$({
    cat /work/flake.nix
    cat /work/flake.lock 2>/dev/null || true
  } | sha256sum | cut -c1-16)
elif [ -f /work/shell.nix ]; then
  kind=shell.nix
  key=$(sha256sum /work/shell.nix | cut -c1-16)
elif [ "$#" -eq 0 ]; then
  echo "sbx: no flake.nix or shell.nix here, so only the base tools;" \
    "add one, or use nix shell nixpkgs#<pkg>" >&2
fi

env=
if [ -n "$kind" ]; then
  env="$cache/$key.sh"
  if [ ! -s "$env" ] || [ -n "$reload" ]; then
    echo "sbx: building the $kind dev shell, cached for the next entry..." >&2
    if [ "$kind" = flake ]; then
      built=$(nix print-dev-env --profile "$cache/$key.profile" /work) || built=
    else
      built=$(nix print-dev-env --profile "$cache/$key.profile" --file /work/shell.nix) || built=
    fi
    if [ -n "$built" ]; then
      printf '%s\n' "$built" > "$env"
    else
      rm -f "$env"
      echo "sbx: dev shell failed to build, continuing with the base tools" >&2
      env=
    fi
  fi
fi

if [ -z "$env" ]; then
  if [ "$#" -gt 0 ]; then exec "$@"; fi
  exec zsh -i
fi

# The dev-env script is bash. Source it in bash, keep the session's temp dir
# (it points TMPDIR at the build sandbox's), then become zsh or the command.
exec bash -c '
  tmp=${TMPDIR:-/tmp}
  source "$1"
  shift
  export TMPDIR=$tmp TMP=$tmp TEMP=$tmp TEMPDIR=$tmp
  if [ "$#" -gt 0 ]; then exec "$@"; fi
  exec zsh -i
' sbx-enter "$env" "$@"
