#!/usr/bin/env bash
# SIS2 task 5: move the pod to the "shortener" service account and run it as a
# systemd (Quadlet) unit that starts at boot.
# Usage: sudo bash sis2/04_migrate_pod_systemd.sh      (ASSUME_YES=1 skips the prompt)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
require_root
cd /

ORIG_USER="${SUDO_USER:-fedora}"
SRC_DIR="/home/${SVC_USER}/src/url-shortener-devops"
QUADLET_DIR="/home/${SVC_USER}/.config/containers/systemd"

if [[ "${ASSUME_YES:-0}" != "1" ]]; then
  echo "This removes the old pod of '${ORIG_USER}' and WIPES ${BASE_DIR}/pgdata (test data only)."
  read -r -p "Continue? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }
fi

step "1/9 Remove the old pod of ${ORIG_USER} (frees port 80)"
ORIG_UID="$(id -u "$ORIG_USER")"
if [[ -d "/run/user/${ORIG_UID}" ]]; then
  runuser -u "$ORIG_USER" -- env XDG_RUNTIME_DIR="/run/user/${ORIG_UID}" \
    podman pod rm -f shortener-pod 2>/dev/null || true
fi

step "2/9 Rootless Podman may bind port 80"
if (( $(sysctl -n net.ipv4.ip_unprivileged_port_start) > 80 )); then
  sysctl -w net.ipv4.ip_unprivileged_port_start=80
  echo "net.ipv4.ip_unprivileged_port_start=80" > /etc/sysctl.d/99-shortener.conf
else
  echo "already allowed"
fi

step "3/9 Start the user manager of ${SVC_USER} (linger = survives logout and reboot)"
loginctl enable-linger "$SVC_USER"
wait_for_user_manager

step "4/9 Fresh database directory owned by the service account"
find "${BASE_DIR}/pgdata" -mindepth 1 -delete
chown "${SVC_USER}:${SVC_USER}" "${BASE_DIR}/pgdata"
chmod 0700 "${BASE_DIR}/pgdata"
restorecon -R "${BASE_DIR}/pgdata"
# uid 999 inside the container = postgres; map it into the service account's namespace
as_svc podman unshare chown 999:999 "${BASE_DIR}/pgdata"

step "5/9 Get the sources as ${SVC_USER}"
command -v git >/dev/null || dnf -y install git
as_svc bash -c '
  mkdir -p "$HOME/src" && cd "$HOME/src"
  if [ -d url-shortener-devops/.git ]; then
    git -C url-shortener-devops pull --ff-only
  else
    git clone "$1"
  fi' _ "$REPO_URL"

step "6/9 Build images and pull Postgres (images are per-user in rootless Podman)"
as_svc bash -c "cd '${SRC_DIR}' && podman build -t localhost/shortener-back:latest ./back && podman build -t localhost/shortener-front:latest ./front"
as_svc podman pull docker.io/library/postgres:16-alpine

step "7/9 Install the pod manifest"
cp "${SRC_DIR}/pod.yaml" "${BASE_DIR}/pod.yaml"
chown shortener:shortener_deploy "${BASE_DIR}/pod.yaml"
chmod 0660 "${BASE_DIR}/pod.yaml"
restorecon -v "${BASE_DIR}/pod.yaml"

step "8/9 Install the Quadlet unit"
install -d -o "$SVC_USER" -g "$SVC_USER" \
  "/home/${SVC_USER}/.config" "/home/${SVC_USER}/.config/containers" "$QUADLET_DIR"
install -m 0644 -o "$SVC_USER" -g "$SVC_USER" \
  "${SCRIPT_DIR}/systemd/shortener.kube" "${QUADLET_DIR}/shortener.kube"
restorecon -R "/home/${SVC_USER}/.config"

step "9/9 Start the unit (the [Install] section makes it start at every boot)"
as_svc systemctl --user daemon-reload
if ! as_svc systemctl --user start shortener.service; then
  echo "Start failed. Quadlet generator output:" >&2
  as_svc /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun || true
  exit 1
fi

sleep 15
step "Result"
as_svc systemctl --user --no-pager status shortener.service || true
as_svc podman pod ps
curl -s -o /dev/null -w "front: HTTP %{http_code}\n" http://localhost/ || true
curl -s -X POST http://localhost/api/shorten -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}' || true
echo
echo "Boot test: sudo reboot, then: sudo /usr/local/sbin/shortener-ctl status"
