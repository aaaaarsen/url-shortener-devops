#!/usr/bin/env bash
# SIS2 task 3: file permissions and sudoers rules for every role.
# Usage: sudo bash sis2/02_permissions_sudoers.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
require_root

step "Directory layout and permissions"
install -d "$BASE_DIR" "$BASE_DIR/pgdata" "$BASE_DIR/logs" "$BASE_DIR/config"

# /opt/shortener: x-only for everyone else (can enter, cannot list); group = admins.
chown shortener:shortener_admins "$BASE_DIR"
chmod 2771 "$BASE_DIR"

# logs: written by the service, read by auditors (setgid keeps the group).
chown -R shortener:shortener_auditors "$BASE_DIR/logs"
find "$BASE_DIR/logs" -type d -exec chmod 2750 {} +
find "$BASE_DIR/logs" -type f -exec chmod 0640 {} +

# config: writable by the deploy group (the automation bot).
chown -R shortener:shortener_deploy "$BASE_DIR/config"
find "$BASE_DIR/config" -type d -exec chmod 2770 {} +
find "$BASE_DIR/config" -type f -exec chmod 0660 {} +

# pod manifest: owned by the service, writable by the deploy group.
touch "$BASE_DIR/pod.yaml"
chown shortener:shortener_deploy "$BASE_DIR/pod.yaml"
chmod 0660 "$BASE_DIR/pod.yaml"

# Environment file with the DB password: root-managed, readable by the service only.
if [[ -f /etc/shortener.env ]]; then
  chown root:shortener /etc/shortener.env
  chmod 0640 /etc/shortener.env
fi

# pgdata is NOT touched here: its ownership is set by 04_migrate_pod_systemd.sh
# through `podman unshare` and must not be changed while the database is running.

restorecon -Rv "$BASE_DIR/logs" "$BASE_DIR/config" >/dev/null
restorecon -v "$BASE_DIR" "$BASE_DIR/pod.yaml" >/dev/null

step "sudo wrapper"
install -m 0755 -o root -g root "${SCRIPT_DIR}/bin/shortener-ctl" /usr/local/sbin/shortener-ctl
ls -l /usr/local/sbin/shortener-ctl

step "sudoers rules (validated before installing)"
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT
install -m 0440 -o root -g root "${SCRIPT_DIR}/sudoers/shortener" "$TMP_SUDOERS"
visudo -cf "$TMP_SUDOERS"
install -m 0440 -o root -g root "$TMP_SUDOERS" /etc/sudoers.d/shortener
visudo -c

step "Result: permissions"
ls -ld "$BASE_DIR" "$BASE_DIR"/* /etc/shortener.env

step "Result: what each role may run with sudo"
for u in admin1 auditor1 automation_bot; do
  echo "--- ${u}"
  sudo -l -U "$u"
done
