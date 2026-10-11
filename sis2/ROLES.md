# Role table (SIS2, task 1)

| Role (account) | Description | Permissions | Superuser permissions |
|---|---|---|---|
| `shortener` | Service account of the whole application. Runs the pod rootless, has no password and no SSH key. | Owns `/opt/shortener`, `logs`, `config`, `pod.yaml`; manages only its own containers and its own user systemd units. | None |
| `postgres` (inside the db container, UID 999) | Service account of PostgreSQL. | Read/write only the `pgdata` volume. | None |
| `nginx` (inside the front container) | Service account of the web front-end. | Reads static files, listens on port 80. | None |
| `shortener_back` (inside the back container, UID 10001) | Service account of the Go API. Created in `back/Dockerfile`, the API no longer runs as root. | Reads its environment, connects to the database. | None |
| `admin1` (group `shortener_admins`) | System administrator. | Group access to `/opt/shortener`; everything else through sudo. | Full sudo (`ALL`), password required |
| `auditor1` (group `shortener_auditors`) | Auditor. | Reads `/opt/shortener/logs` only. | `sudo shortener-ctl status` and `sudo shortener-ctl logs`, password required |
| `automation_bot` (group `shortener_deploy`) | Deploy bot, SSH key only. | Writes `/opt/shortener/config` and `/opt/shortener/pod.yaml`. | `sudo shortener-ctl status/logs/restart/update`, no password |

`shortener-ctl` is a root-owned wrapper that accepts only four fixed actions, so sudoers can allow
exact commands without wildcards (a wildcard in sudoers lets users add arguments).
