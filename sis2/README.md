# SIS2: users, permissions, SSH, systemd

All actions are scripts. Run them on the VM, in this order, from a clone of the repository:

    cd ~/url-shortener-devops && git pull
    sudo bash sis2/01_groups_users.sh          # task 2: groups and users
    sudo bash sis2/02_permissions_sudoers.sh   # task 3: file permissions, sudoers
    sudo bash sis2/03_ssh_automation.sh /tmp/automation_bot_key.pub   # task 4: SSH key
    sudo bash sis2/04_migrate_pod_systemd.sh   # task 5: pod under `shortener`, systemd unit

The key for task 4 is created on your own machine:

    ssh-keygen -t ed25519 -f ~/.ssh/automation_bot_key -N ""
    scp -i ~/.ssh/shortener_key ~/.ssh/automation_bot_key.pub fedora@<public-ip>:/tmp/

## Files

| File | Purpose |
|---|---|
| `ROLES.md` | Role table (task 1) |
| `01_groups_users.sh` | Groups and one user per role |
| `02_permissions_sudoers.sh` | `chown`/`chmod`/setgid, installs sudoers and the wrapper |
| `sudoers/shortener` | Rules installed to `/etc/sudoers.d/shortener` |
| `bin/shortener-ctl` | Root-owned wrapper: `status`, `logs`, `restart`, `update` |
| `03_ssh_automation.sh` | Public key for `automation_bot`, sshd hardening |
| `04_migrate_pod_systemd.sh` | Moves the pod to `shortener`, installs the Quadlet unit |
| `systemd/shortener.kube` | Quadlet unit, systemd generates `shortener.service` from it |

## Screenshots for the report

1. Task 2: the "Result" part of `01` (`id` of every user, `getent group`).
2. Task 3: the "Result" parts of `02` (`ls -ld`, `sudo -l -U ...`) and the negative test
   `sudo -u auditor1 cat /opt/shortener/config/x` (permission denied).
3. Task 4: `ssh -i ~/.ssh/automation_bot_key automation_bot@<ip> 'id; sudo -n /usr/local/sbin/shortener-ctl status'`
   and `sshd -T` lines from `03`.
4. Task 5: the "Result" part of `04`, `systemctl --user cat shortener.service` (generated unit),
   and the same status after `sudo reboot`.

Never screenshot `/root/sis2_passwords.txt`.
