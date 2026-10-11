#!/usr/bin/env bash
# Shared helpers for the SIS2 scripts. Sourced, not executed.

SVC_USER="shortener"
# shellcheck disable=SC2034  # used by the scripts that source this file
BASE_DIR="/opt/shortener"
# shellcheck disable=SC2034
REPO_URL="https://github.com/aaaaarsen/url-shortener-devops.git"

step() { echo; echo "==> $*"; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo bash $0" >&2
    exit 1
  fi
}

svc_uid() { id -u "$SVC_USER"; }

# Run a command as the service account with a working user-session environment.
# Rootless Podman and `systemctl --user` need XDG_RUNTIME_DIR and the user bus,
# which exist only while the user manager runs (we enable linger for that).
as_svc() {
  local uid
  uid="$(svc_uid)"
  (
    cd "/home/${SVC_USER}" || exit 1
    runuser -u "${SVC_USER}" -- env \
      HOME="/home/${SVC_USER}" \
      XDG_RUNTIME_DIR="/run/user/${uid}" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
      "$@"
  )
}

wait_for_user_manager() {
  local uid
  uid="$(svc_uid)"
  for _ in $(seq 1 30); do
    [[ -S "/run/user/${uid}/bus" ]] && return 0
    sleep 1
  done
  echo "User manager of ${SVC_USER} did not start (no /run/user/${uid}/bus)" >&2
  return 1
}
