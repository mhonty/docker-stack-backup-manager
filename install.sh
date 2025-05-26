#!/usr/bin/env bash
set -euo pipefail

GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
NC='\e[0m'

BIN_PATH="/usr/local/bin/dsbm"
CONFIG_DIR="/etc/dsbm"
CONFIG_FILE="${CONFIG_DIR}/dsbmConfig.yml"
SCRIPT_SOURCE="backup.sh"
CONFIG_TEMPLATE="dsbmConfig.yml.example"

echo -e "${GREEN}Docker Stack Backup Manager - Installer${NC}"
echo "--------------------------------------------"

# Must be run as root
if [ "$(id -u)" -ne 0 ]; then
  echo -e "${RED}Error: This installer must be run as root (or with sudo).${NC}"
  exit 1
fi

# Check for required tools
MISSING=()

for cmd in yq docker zip; do
  if ! command -v "$cmd" &> /dev/null; then
    MISSING+=("$cmd")
  fi
done

if (( ${#MISSING[@]} > 0 )); then
  echo -e "${RED}Error: The following required tools are missing:${NC}"
  for m in "${MISSING[@]}"; do
    echo -e " - ${RED}$m${NC}"
  done
  echo -e "${YELLOW}Please install them and try again.${NC}"
  exit 1
fi

# Ensure source script exists
if [ ! -f "$SCRIPT_SOURCE" ]; then
  echo -e "${RED}Error: '${SCRIPT_SOURCE}' not found in current directory.${NC}"
  exit 1
fi

# Install main script
echo -e "${YELLOW}Installing main script to ${BIN_PATH}...${NC}"
install -m 755 "$SCRIPT_SOURCE" "$BIN_PATH"

# Create config directory if needed
mkdir -p "$CONFIG_DIR"

# Install config template
if [ ! -f "$CONFIG_FILE" ]; then
  if [ -f "$CONFIG_TEMPLATE" ]; then
    echo -e "${YELLOW}Creating default config at ${CONFIG_FILE}...${NC}"
    cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"
  else
    echo -e "${RED}Warning: No default config found (${CONFIG_TEMPLATE}).${NC}"
    echo -e "${RED}You must create one manually in ${CONFIG_FILE}.${NC}"
  fi
else
  echo -e "${YELLOW}Config already exists at ${CONFIG_FILE}, skipping.${NC}"
fi

echo -e "\n${GREEN}✅ Installation complete!${NC}"
echo -e "You can now run ${YELLOW}dsbm${NC} to execute the backup."
echo -e "Edit your config at: ${CONFIG_FILE}"
