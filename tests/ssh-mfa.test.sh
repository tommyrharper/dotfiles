#!/usr/bin/env bash
# Askpass mode of home/.local/bin/ssh-mfa: right secret for each login prompt.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

tmp=$(dotfiles_test_tmproot ssh-mfa)
mkdir -p "$tmp/bin" "$tmp/creds"
printf 'hunter2\n' > "$tmp/creds/password"
printf 'JBSWY3DPEHPK3PXP\n' > "$tmp/creds/totp"
printf '#!/bin/sh\n[ "$*" = "--totp -b JBSWY3DPEHPK3PXP" ] && echo 123456\n' > "$tmp/bin/oathtool"
chmod +x "$tmp/bin/oathtool"

askpass() { PATH="$tmp/bin:$PATH" SSH_MFA_CREDS="$tmp/creds" "$ROOT/home/.local/bin/ssh-mfa" "$1"; }

[ "$(askpass "Password: ")" = hunter2 ] || fail "password prompt not answered"
[ "$(askpass "(user@host) Password: ")" = hunter2 ] || fail "prefixed password prompt not answered"
[ "$(askpass "TOTP Verification Code: ")" = 123456 ] || fail "TOTP prompt not answered"
askpass "Are you sure you want to continue connecting (yes/no)?" 2>/dev/null &&
  fail "unknown prompt must fail, not guess"

pass "ssh-mfa askpass answers password and TOTP prompts"
