#!/usr/bin/env bash
# Print the CAA records to add in Cloudflare for h.lalvesl.com.
#
# CAA tells every certificate authority in the world who is allowed to issue for
# a name. Without it, anyone holding the Cloudflare DNS token can pass DNS-01 and
# get a valid certificate for these names from any CA; revoking the token later
# does not invalidate what was already issued. With accounturi= the record also
# pins issuance to one ACME account, so the stolen token stops being sufficient.
#
#   ./cloud/orangepi/caa-records.sh                  # bootstrap records
#   ./cloud/orangepi/caa-records.sh lalvesl@<board>  # final, pinned records
#
# Order matters. accounturi= names an ACME account, and that account only exists
# after the board has successfully issued once -- publish the pinned record too
# early and nothing can ever be issued. So: bootstrap records, deploy, then come
# back and run this against the board.
set -euo pipefail

domain="h.lalvesl.com"
ca="letsencrypt.org"
target="${1:-}"

emit() {
  local params="$1"
  cat <<EOF

  Type    Name              Value
  ----    ----              -----
  CAA     ${domain}    0 issue "${ca}${params}"
  CAA     ${domain}    0 issuewild "${ca}${params}"

In Cloudflare these are two records on ${domain}, flag 0, tags "issue" and
"issuewild". Both are needed: when issuewild is present it governs wildcards
on its own, and *.${domain} is the name that matters here.

Set at ${domain} rather than the zone apex, so the rest of lalvesl.com is
left unconstrained.
EOF
}

if [ -z "$target" ]; then
  cat >&2 <<EOF

Bootstrap records -- restrict issuance to ${ca} over DNS-01, without
pinning an account yet. Publish these before the first deploy.
EOF
  emit "; validationmethods=dns-01"
  cat >&2 <<EOF

Once the board has issued its first certificate, run:

    $0 lalvesl@<board-address>

to get the pinned version.

EOF
  exit 0
fi

echo "reading the ACME account URI from ${target}..." >&2
uri=$(ssh "$target" \
  "sudo find /var/lib/acme/.lego/accounts -name account.json -print0 \
   | xargs -0 -r sudo grep -ho 'https://[^\"]*/acme/acct/[0-9]*'" \
  2>/dev/null | sort -u)

if [ -z "$uri" ]; then
  echo "no ACME account found on ${target} -- has a certificate been issued yet?" >&2
  echo "check: systemctl status acme-${domain}.service" >&2
  exit 1
fi

if [ "$(printf '%s\n' "$uri" | wc -l)" -ne 1 ]; then
  echo "more than one ACME account on ${target}:" >&2
  printf '  %s\n' $uri >&2
  echo "pin them all, or remove the stale ones from /var/lib/acme/.lego/accounts" >&2
  exit 1
fi

cat >&2 <<EOF

Pinned records -- only this board's ACME account may issue for ${domain}.
Replace the bootstrap records with these.
EOF
emit "; validationmethods=dns-01; accounturi=${uri}"
cat >&2 <<EOF

Note what this does and does not cover. Certificates issued before the record
went up stay valid until they expire; with the shortlived profile that is under
seven days. Re-running this after rebuilding the board is required if the ACME
account was not preserved -- /var/lib/acme must survive, or issuance breaks
against the pinned record.

EOF
