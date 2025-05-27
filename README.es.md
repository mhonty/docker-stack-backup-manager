# Docker Stack Backup Manager

**Docker Stack Backup Manager (DSBM)** es una herramienta en Bash para realizar copias de seguridad automatizadas y configurables de proyectos Docker.  
Permite respaldar:

- Archivos de configuración y código fuente del proyecto.
- Volúmenes persistentes de Docker.
- Bases de datos MariaDB/MySQL (desde contenedores).
- Varios stacks definidos desde un archivo YAML centralizado.

---

## 📦 Características

- Configuración mediante YAML.
- Soporte para múltiples stacks.
- Copia de bases de datos usando `docker exec`.
- Respaldo de volúmenes como archivos `.tar.gz`.
- Retención configurable de backups antiguos.
- Rotación automática de copias.
- Pensado para integrarse con sistemas de backup externos.

---

## 🛠 Requisitos

- Linux (probado en openSUSE y distribuciones Debian)
- [`bash`](https://www.gnu.org/software/bash/)
- [`yq`](https://github.com/mikefarah/yq) (`v4.x`)
- [`docker`](https://docs.docker.com/)
- [`zip`](https://linux.die.net/man/1/zip)

---

## 📁 Instalación

Clona el repositorio y ejecuta el instalador:

```bash
git clone https://github.com/youruser/docker-stack-backup-manager.git
cd docker-stack-backup-manager
sudo ./install.sh
```

Este proceso:

- Instala el script como `/usr/local/bin/dsbm`
- Copia un archivo de ejemplo de configuración en `/etc/dsbm/dsbmConfig.yml`
- Crea los directorios necesarios bajo `/etc/dsbm` y `/var/backups/dsbm` (a menos que se configure otra ruta)

---

## 🧪 Uso

Una vez instalado y configurado:

```bash
dsbm
```

El script:

- Lee `/etc/dsbm/dsbmConfig.yml`
- Respalda los stacks definidos
- Guarda el último backup en `$backup_path/last`
- Mueve copias anteriores a `$backup_path/old` y borra las que superen el número de días indicado

## Códigos de salida

`DSBM` devuelve los siguientes códigos de salida para indicar el resultado de la operación de respaldo:

| Código | Significado                           | Detalles                                                   |
|--------|----------------------------------------|-------------------------------------------------------------|
| 0      | Éxito                                  | Todos los stacks fueron respaldados sin errores ni avisos. |
| 1      | Error crítico                          | Todos los stacks fallaron al intentar respaldarse.         |
| 2      | Éxito parcial o errores no críticos    | Al menos un stack falló, o se omitieron volúmenes/bases de datos. |

Esto permite que `DSBM` se utilice de forma segura en scripts automatizados, tareas programadas (`cronjobs`) o sistemas de monitorización externos.

---

## ⚙️ Configuración

El archivo principal de configuración está en:

```
/etc/dsbm/dsbmConfig.yml
```

### Ejemplo:

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
  - stack_name: mi_proyecto
    stack_dir: /opt/docker/mi_proyecto
    volumes:
      - mi_proyecto_datos
      - mi_proyecto_uploads
    db_container: db_mi_proyecto
    db_user: root
    db_pass: miclave
    dbs:
      - proyecto_db
      - wordpress
```

### Notas:

- `volumes`, `db_container`, `db_user`, `db_pass` y `dbs` son opcionales.
- Si no se define la configuración de la base de datos, simplemente se omite.
- Si no hay volúmenes listados, solo se respalda el directorio del proyecto.

---

## 🔒 Permisos

- El usuario que ejecuta `dsbm` debe tener acceso a Docker (habitualmente mediante el grupo `docker`).
- Asegúrate de que la ruta `backup_path` es escribible.

---

## 🧾 Licencia

Este proyecto está licenciado bajo la licencia MIT. Consulta [`LICENSE`](LICENSE) para más detalles.

---

## 👤 Autor

Pedro Montalvo – [@mhonty](https://github.com/mhonty)

¡Se agradecen contribuciones y sugerencias!
