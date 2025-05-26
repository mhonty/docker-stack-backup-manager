# Docker Stack Backup Manager

**Docker Stack Backup Manager (DSBM)** is a Bash-based utility for performing automated and configurable backups of Docker-based projects.  
It supports backing up:

- Project source/configuration files.
- Docker named volumes.
- MariaDB/MySQL databases (via container access).
- Multiple stacks from a centralized YAML configuration.

---

## 📦 Features

- YAML-based configuration.
- Multiple stack support.
- Database dumps via Docker exec.
- Volume tarball creation.
- Configurable backup retention policy.
- Automatic rotation of daily snapshots.
- Integration-ready for external backup systems.

---

## 🛠 Requirements

- Linux (tested on openSUSE, Debian-based distros)
- [`bash`](https://www.gnu.org/software/bash/)
- [`yq`](https://github.com/mikefarah/yq) (`v4.x`)
- [`docker`](https://docs.docker.com/)
- [`zip`](https://linux.die.net/man/1/zip)

---

## 📁 Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/youruser/docker-stack-backup-manager.git
cd docker-stack-backup-manager
sudo ./install.sh
```

This will:

- Install the script to `/usr/local/bin/dsbm`
- Copy an example config to `/etc/dsbm/dsbmConfig.yml`
- Create necessary directories under `/etc/dsbm` and `/var/backups/dsbm` (unless configured otherwise)

---

## 🧪 Usage

Once installed and configured:

```bash
dsbm
```

The script will:

- Read `/etc/dsbm/dsbmConfig.yml`
- Backup configured stacks
- Store the latest backup under `$backup_path/last`
- Rotate old backups to `$backup_path/old`

---

## ⚙️ Configuration

The main configuration file is located at:

```
/etc/dsbm/dsbmConfig.yml
```

### Example:

```yaml
global:
  backup_path: /var/backups/dsbm
  keep_days: 14
  exclude_paths:
    - "*.log"
    - "*.zip"
    - ".git"
    - ".vscode"

stacks:
  - stack_name: my_project
    stack_dir: /opt/docker/my_project
    volumes:
      - my_project_data
      - my_project_uploads
    db_container: db_my_project
    db_user: root
    db_pass: mysecret
    dbs:
      - project_db
      - wordpress
```

### Notes:

- `volumes`, `db_container`, `db_user`, `db_pass`, and `dbs` are optional.
- If database configuration is missing, database backup is skipped.
- If no volumes are listed, only files will be backed up.

---

## 🔒 Permissions

- The user running `dsbm` must have access to Docker (typically by being in the `docker` group).
- Ensure the `backup_path` is writable by the executing user.

---

## 🧾 License

This project is licensed under the MIT License. See [`LICENSE`](LICENSE) for details.

---

## 👤 Author

Pedro Montalvo – [@mhonty](https://github.com/mhonty)

Contributions and feedback welcome!
