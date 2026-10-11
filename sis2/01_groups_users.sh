#!/usr/bin/env bash
# SIS2 task 2: create groups and at least one user for every role.
# Usage: sudo bash sis2/01_groups_users.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
require_root

PASSWORD_FILE="/root/sis2_passwords.txt"
ROLE_GROUPS=(shortener_admins shortener_auditors shortener_deploy)

touch "$PASSWORD_FILE"
chmod 600 "$PASSWORD_FILE"

random_password() { head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9'; }

# create_user NAME PRIMARY_GROUP MODE   (MODE: password | locked)
create_user() {
  local name="$1" grp="$2" mode="$3" pw
  if id "$name" >/dev/null 2>&1; then
    echo "exists:  $name"
    return 0
  fi
  useradd -m -g "$grp" -s /bin/bash "$name"
  echo "created: $name (primary group: $grp)"
  case "$mode" in
    password)
      pw="$(random_password)"
      echo "${name}:${pw}" | chpasswd
      echo "${name} ${pw}" >> "$PASSWORD_FILE"
      ;;
    locked)
      passwd -l "$name" >/dev/null
      ;;
  esac
}

step "Groups"
for g in shortener "${ROLE_GROUPS[@]}"; do
  if getent group "$g" >/dev/null; then
    echo "exists:  $g"
  else
    groupadd "$g"
    echo "created: $g"
  fi
done

step "Users (one per role)"
# Service account: runs the pod, no password, no SSH key.
create_user shortener       shortener           locked
# Human roles: password only used for sudo, SSH login is key-only on this VM.
create_user admin1          shortener_admins    password
create_user auditor1        shortener_auditors  password
# Automation account: SSH key only, no password at all.
create_user automation_bot  shortener_deploy    locked

# Rootless Podman needs subordinate UID/GID ranges for the service account.
if ! grep -q "^${SVC_USER}:" /etc/subuid; then
  usermod --add-subuids 200000-265535 --add-subgids 200000-265535 "$SVC_USER"
  echo "added subordinate IDs for ${SVC_USER}"
fi

step "Result"
for u in shortener admin1 auditor1 automation_bot; do id "$u"; done
echo
getent group shortener shortener_admins shortener_auditors shortener_deploy
echo
grep -E "^(shortener|admin1|auditor1|automation_bot):" /etc/passwd
echo
echo "Generated passwords are in ${PASSWORD_FILE} (root only). Do not commit or screenshot them."
