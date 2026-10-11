#!/usr/bin/env bash
# SIS2 task 4: SSH key access for the automation account.
# Usage: sudo bash sis2/03_ssh_automation.sh /path/to/automation_bot_key.pub
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
require_root

PUBKEY_FILE="${1:-}"
if [[ -z "$PUBKEY_FILE" || ! -f "$PUBKEY_FILE" ]]; then
  echo "usage: sudo bash $0 /path/to/automation_bot_key.pub" >&2
  exit 1
fi

BOT="automation_bot"
id "$BOT" >/dev/null
BOT_HOME="$(getent passwd "$BOT" | cut -d: -f6)"
BOT_GROUP="$(id -gn "$BOT")"

step "Install the public key for ${BOT}"
install -d -m 0700 -o "$BOT" -g "$BOT_GROUP" "${BOT_HOME}/.ssh"
touch "${BOT_HOME}/.ssh/authorized_keys"
if ! grep -qxF "$(cat "$PUBKEY_FILE")" "${BOT_HOME}/.ssh/authorized_keys"; then
  cat "$PUBKEY_FILE" >> "${BOT_HOME}/.ssh/authorized_keys"
fi
chown "$BOT:$BOT_GROUP" "${BOT_HOME}/.ssh/authorized_keys"
chmod 0600 "${BOT_HOME}/.ssh/authorized_keys"
# SELinux must label ~/.ssh correctly, otherwise sshd refuses the key.
restorecon -Rv "${BOT_HOME}/.ssh"
ls -la "${BOT_HOME}/.ssh"

step "sshd hardening (validated before reload)"
DROPIN="/etc/ssh/sshd_config.d/00-sis2.conf"
cat > "$DROPIN" <<'CONF'
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
CONF
if ! sshd -t; then
  rm -f "$DROPIN"
  echo "sshd config check failed, drop-in removed" >&2
  exit 1
fi
systemctl reload sshd
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|pubkeyauthentication) '

echo
echo "Test from your own machine (keep this session open until it works):"
echo "  ssh -i ~/.ssh/automation_bot_key ${BOT}@<public-ip> 'id; sudo -n /usr/local/sbin/shortener-ctl status'"
