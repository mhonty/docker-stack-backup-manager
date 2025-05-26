#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Docker Stack Backup Manager
# -----------------------------------------------------------------------------
# This script performs automated and configurable backups of Docker stacks,
# including persistent volumes, configuration files, and databases.
#
# - YAML-based configuration.
# - Supports multiple stacks.
# - Generates compressed backups with automatic rotation.
# - Optimized for integration with external backup services.
#
# Author: Pedro Montalvo
# Date: 2025-05-26
# License: MIT
# -----------------------------------------------------------------------------

set -Eeuo pipefail
IFS=$'\n\t'

tput civis 2>/dev/null || true
trap 'tput cnorm 2>/dev/null || true' EXIT

GREEN='\e[32m'; 
RED='\e[31m'; 
BLUE='\e[34m'; 
YELLOW='\e[33m';
NC='\e[0m';
TITLE=$'\033[30;104m';

run_with_spinner() {
  local message="$1"; shift
  local cmd=( "$@" )

  local spinner=( '|' '/' '-' '\' ); local i=0
  local indent=$'\t'

  if [[ "$message" == $'\t'* ]]; then
    indent+=$'\t'
    message="${message#$'\t'}" 
  fi

  "${cmd[@]}" & 
  local pid=$!

  trap "kill $pid 2>/dev/null" SIGINT SIGTERM

  printf "%s[%s] %s" "$indent" "${spinner[i]}" "$message"
  i=1

  while kill -0 "$pid" 2>/dev/null; do
    printf "\r%s[%s] %s" "$indent" "${spinner[i]}" "$message"
    i=$(( (i + 1) % ${#spinner[@]} ))
    sleep 0.2
  done

  wait "$pid"; local code=$?

  if [ $code -eq 0 ]; then
    printf "\r%s[${GREEN}✓${NC}] %s\n" "$indent" "$message"
  else
    printf "\r%s[${RED}✗${NC}] %s\n" "$indent" "$message"
    exit $code
  fi

  trap - SIGINT SIGTERM
}

clear

left="Docker Stack Backup Manager V 1.0.0"
right="By Mhonty 2024"

cols=$(tput cols)

space=$(( cols - ${#left} - ${#right} ))
(( space < 1 )) && space=1

printf "%b%*s%b\n" "$TITLE" "$cols" "" "$NC"

printf "%b%s%*s%s" \
  "$TITLE" \
  "$left" \
  "$space" "" \
  "$right" \
  "$NC"

printf "%b%*s%b\n\n\n" "$TITLE" "$cols" "" "$NC"

CONFIG_FILE="/etc/dsbm/dsbmConfig.yml"

if ! command -v yq &> /dev/null; then
  echo -e "${RED}Error: 'yq' is not installed. Please install it to continue.${NC}"
  exit 1
fi

if ! command -v docker &> /dev/null; then
  echo -e "${RED}Error: Docker is not installed. Please install it to continue.${NC}"
  exit 1
fi

if ! command -v zip &> /dev/null; then
  echo -e "${RED}Error: zip is not installed. Please install it to continue.${NC}"
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo -e "${RED}Error: Configuration file not found at $CONFIG_FILE${NC}"
  exit 1
fi

if ! docker info &>/dev/null; then
  echo -e "${RED}Error: Current user cannot access Docker. Add it to the 'docker' group or run as root.${NC}"
  exit 1
fi

BACKUP_DEST=$(yq '.global.backup_path' "$CONFIG_FILE")
if [ ! -w "$BACKUP_DEST" ] && [ ! -d "$BACKUP_DEST" ]; then
  echo -e "${RED}Error: Cannot write to backup path: $BACKUP_DEST${NC}"
  echo -e "${RED}Make sure the directory exists and the user has write permissions.${NC}"
  exit 1
fi
if [ -d "$BACKUP_DEST" ] && [ ! -w "$BACKUP_DEST" ]; then
  echo -e "${RED}Error: Backup path exists but is not writable: $BACKUP_DEST${NC}"
  exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
WORKDIR=$(mktemp -d "/tmp/DSBM_backup_${TIMESTAMP}_XXXX")
raw_keep_days=$(yq '.global.keep_days' "$CONFIG_FILE" 2>/dev/null || echo "")
if [[ -z "$raw_keep_days" || "$raw_keep_days" == "null" ]]; then
  KEEP_DAYS=14
  echo -e "[⚠️ ]${YELLOW}Warning: 'keep_days' not set. Using default: $KEEP_DAYS${NC}"
else
  if ! [[ "$raw_keep_days" =~ ^[0-9]+$ ]]; then
    echo -e "[${RED}✗${NC}]${RED} Error: 'keep_days' must be a positive integer. Using default: 14${NC}"
    KEEP_DAYS=14
  else
    KEEP_DAYS="$raw_keep_days"
  fi
fi


run_with_spinner "Preparing backup directories" \
  bash -c "mkdir -p '$BACKUP_DEST' &&  mkdir -p '$BACKUP_DEST/last' && mkdir -p '$BACKUP_DEST/old' && mv '$BACKUP_DEST/last'/* '$BACKUP_DEST/old/' 2>/dev/null || true"

mapfile -t STACKS_NAMES < <(yq '.stacks[].stack_name' "$CONFIG_FILE")
mapfile -t EXCLUDES < <(yq '.global.exclude_paths // [] | .[]' "$CONFIG_FILE")
exclude_args=""
for ex in "${EXCLUDES[@]}"; do
  exclude_args+=" --exclude='${ex}'"
done

TOTAL_STACKS=${#STACKS_NAMES[@]}
FAILED_STACKS=0
HAS_ERRORS=false

for name in "${STACKS_NAMES[@]}"; do

  STACK_NAME=$(yq ".stacks[] | select(.stack_name == \"$name\") | .stack_name" "$CONFIG_FILE")
  STACK_DIR=$(yq ".stacks[] | select(.stack_name == \"$name\") | .stack_dir" "$CONFIG_FILE")
  if [[ -z "$STACK_NAME" ]]; then
    echo -e "[${RED}✗${NC}]${RED} Missing 'stack_name' for one of the entries. Skipping stack.${NC}"
    HAS_ERRORS=true
    ((FAILED_STACKS++))
    continue
  fi

  if [[ -z "$STACK_DIR" ]]; then
    echo -e "[${RED}✗${NC}]${RED} Missing 'stack_dir' for stack '${STACK_NAME}'. Skipping stack.${NC}"
    HAS_ERRORS=true
    ((FAILED_STACKS++))
    continue
  fi

  mapfile -t VOLUMES < <(yq ".stacks[] | select(.stack_name == \"$name\") | .volumes[]" "$CONFIG_FILE")
  DB_CONTAINER=$(yq ".stacks[] | select(.stack_name == \"$name\") | .db_container // \"\"" "$CONFIG_FILE")
  mapfile -t DBS < <(yq ".stacks[] | select(.stack_name == \"$name\") | .dbs[]" "$CONFIG_FILE")
  DB_USER=$(yq ".stacks[] | select(.stack_name == \"$name\") | .db_user // \"\"" "$CONFIG_FILE")
  DB_PASS=$(yq ".stacks[] | select(.stack_name == \"$name\") | .db_pass // \"\"" "$CONFIG_FILE")


  echo "----------------------------------------------------------------------"
  echo -e "${BLUE}Starting backup for ${name}...${NC}"

  if [[ ! -d "$STACK_DIR" ]]; then
    echo -e "[${RED}✗${NC}]${RED} Error: Stack directory does not exist: $STACK_DIR${NC}"
    ((FAILED_STACKS++))
    continue
  fi

  if [[ ! -r "$STACK_DIR" ]]; then
    echo -e "${RED}Error: Stack directory is not readable: $STACK_DIR${NC}"
    ((FAILED_STACKS++))
    continue
  fi

  ZIP_NAME="${name}_backup_${TIMESTAMP}.zip"

  run_with_spinner "Backing up configuration files and source code" \
    tar -czf "$WORKDIR/stack_dir.tar.gz" -C "$STACK_DIR" .

  if [ ${#VOLUMES[@]} -eq 0 ]; then
    echo -e "\t[⚠️ ] No volumes to backup."
  else
    echo -e "\tBacking up persistent volumes:"
    for vol in "${VOLUMES[@]}"; do
      if ! docker volume inspect "$vol" &>/dev/null; then
        echo -e "\t\t[${RED}✗${NC}]${RED} Volume '${vol}' does not exist. Skipping.${NC}"
        HAS_ERRORS=true
      fi

      run_with_spinner $'\t'"Volume: ${vol}" \
        docker run --rm \
          -v "${vol}":/volume:ro \
          -v "${WORKDIR}":/backup \
          alpine sh -c "cd /volume && tar -czf /backup/volume_${vol}.tar.gz ${exclude_args} ."
    done
  fi

  if [ ${#DBS[@]} -eq 0 ]; then
    echo -e "\t[⚠️ ] No databases to backup."
  else
    echo -e "\tBacking up databases:"
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
      echo -e "\t\t[${RED}✗${NC}]${RED} Database container '${DB_CONTAINER}' does not exist. Skipping database backup.${NC}"
      HAS_ERRORS=true
    else
      DB_EXISTS=$(docker exec "$DB_CONTAINER" sh -c \
        "mysql -u${DB_USER} -p${DB_PASS} -e \"SHOW DATABASES LIKE '${db}';\" 2>/dev/null | grep -w '${db}' || true")
      if [[ -z "$DB_EXISTS" ]]; then
        echo -e "\t\t[${RED}✗${NC}]${RED} Database '${db}' does not exist in '${DB_CONTAINER}' or the credentials are not valid. Skipping.${NC}"
        HAS_ERRORS=true
      else
        for db in "${DBS[@]}"; do
          DUMP_FILE="${WORKDIR}/db_${db}.sql"

          run_with_spinner $'\t'"Dumping database ${db}" \
            bash -c '
              SHELL_BIN=$(docker exec "$1" sh -c "command -v bash || command -v sh")
              DUMP_BIN=$(docker exec "$1" "$SHELL_BIN" -c "command -v mariadb-dump || command -v mysqldump")
              docker exec "$1" "$SHELL_BIN" -c "\"$DUMP_BIN\" -u\$0 -p\$1 --databases \$2" "$2" "$3" "$4" > "$5"
            ' _ "$DB_CONTAINER" "$DB_USER" "$DB_PASS" "$db" "$DUMP_FILE"
        done
      fi
    fi
  fi

  run_with_spinner "Creating final ZIP archive" \
    bash -c "cd '$WORKDIR' && zip -rq '$BACKUP_DEST/last/$ZIP_NAME' ."

  run_with_spinner "Cleaning up temporary files" \
    bash -c "rm -rf \"$WORKDIR\"/* || true"
done

echo "----------------------------------------------------------------------"

run_with_spinner "Removing temporary backup directory" \
  rm -rf "$WORKDIR"

run_with_spinner "Deleting backups older than ${KEEP_DAYS} days" \
  find "$BACKUP_DEST/old" -type f -name "*_backup_*.zip" -mtime +"$KEEP_DAYS" -delete

if [ "$FAILED_STACKS" -eq "$TOTAL_STACKS" ]; then
  echo -e "${RED}All backups failed. Exit status: 1${NC}"
  exit 1
elif [ "$HAS_ERRORS" = true ] || [ "$FAILED_STACKS" -gt 0 ]; then
  echo -e "${YELLOW}Some stacks or tasks failed (${FAILED_STACKS}/${TOTAL_STACKS}). Exit status: 2${NC}"
  exit 2
else
  echo -e "${GREEN}All backups completed successfully. Exit status: 0${NC}"
  exit 0
fi

