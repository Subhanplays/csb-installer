#!/bin/bash

# SubhanPlays Pterodactyl Installer - Wings Installation
# Version: 1.0.0

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="→"

# Variables
WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"
TMP_DIR="/tmp/subhanplays-pterodactyl"

# Cleanup
cleanup() {
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT INT TERM

# Helper functions
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
    wait $pid
    return $?
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[${ICON_ERROR}] This script must be run as root${NC}"
        exit 1
    fi
}

# Main installation
install_wings() {
    clear
    echo -e "${CYAN}${BOLD}PTERODACTYL WINGS INSTALLATION${NC}"
    echo ""
    
    check_root
    
    # Get panel URL
    while true; do
        read -p "Enter your Pterodactyl Panel URL (e.g., https://panel.example.com): " PANEL_URL
        if [[ "$PANEL_URL" =~ ^https?:// ]]; then
            break
        fi
        echo -e "${RED}[${ICON_ERROR}] Invalid URL format. Must start with http:// or https://${NC}"
    done
    
    read -p "Enter node name: " NODE_NAME
    
    echo ""
    echo -e "${YELLOW}[${ICON_WARNING}] IMPORTANT: You must create a node in the Pterodactyl Panel first!${NC}"
    echo -e "${WHITE}1. Go to Admin Panel -> Nodes -> Create New${NC}"
    echo -e "${WHITE}2. Configure the node and generate a configuration${NC}"
    echo -e "${WHITE}3. Copy the configuration command or token${NC}"
    echo ""
    read -p "Press Enter when ready..."
    
    # Install Docker
    echo -e "${BLUE}[${ICON_ARROW}] Checking Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[${ICON_WARNING}] Docker not found. Installing...${NC}"
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 &
        spinner $!
        systemctl start docker > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}[${ICON_ERROR}] Docker is not running${NC}"
        exit 1
    fi
    echo -e "${GREEN}[${ICON_SUCCESS}] Docker is running${NC}"
    
    # Install dependencies
    echo -e "${BLUE}[${ICON_ARROW}] Installing dependencies...${NC}"
    apt-get update -y > /dev/null 2>&1
    apt-get install -y curl wget tar unzip > /dev/null 2>&1 &
    spinner $!
    
    # Download Wings
    echo -e "${BLUE}[${ICON_ARROW}] Downloading Wings...${NC}"
    mkdir -p "$TMP_DIR"
    
    local latest_wings=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest | \
        grep "browser_download_url.*linux_amd64" | cut -d'"' -f4)
    
    if [[ -f "$WINGS_BIN" ]]; then
        cp "$WINGS_BIN" "${WINGS_BIN}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    wget -q -O "$WINGS_BIN" "$latest_wings"
    chmod u+x "$WINGS_BIN"
    echo -e "${GREEN}[${ICON_SUCCESS}] Wings downloaded${NC}"
    
    # Configure Wings
    echo -e "${BLUE}[${ICON_ARROW}] Configuring Wings...${NC}"
    mkdir -p "$WINGS_DIR"
    mkdir -p /var/lib/pterodactyl/volumes
    
    cat > "$WINGS_DIR/config.yml" <<EOF
debug: false
app_name: "${NODE_NAME}"
uuid: "$(cat /proc/sys/kernel/random/uuid)"
token_id: ""
token: ""
api:
  host: 0.0.0.0
  port: 8080
  ssl:
    enabled: false
    cert: ""
    key: ""
  upload_limit: 100
remote: "${PANEL_URL}"
system:
  root_directory: /var/lib/pterodactyl
  log_directory: /var/log/pterodactyl
  data: /var/lib/pterodactyl/volumes
  archive_directory: /var/lib/pterodactyl/archives
  backup_directory: /var/lib/pterodactyl/backups
  tmp_directory: /tmp/pterodactyl
  username: pterodactyl
  timezone: UTC
  sftp:
    bind_address: 0.0.0.0
    bind_port: 2022
    read_only: false
  crash_detection:
    enabled: true
    detect_clean_exit_as_crash: true
    timeout: 60
docker:
  network:
    name: pterodactyl_nw
    is_internal: false
    interfaces:
      v4:
        subnet: 172.18.0.0/16
        gateway: 172.18.0.1
      v6:
        subnet: fd00::/64
        gateway: fd00::1
  domainname: ""
  registries: {}
  tmpfs_size: 100
  container_pid_limit: 512
  installer_limits:
    memory: 1024
    cpu: 100
  overhead:
    override: false
    default_multiplier: 1.05
    multipliers: {}
throttles:
  enabled: false
  lines: 2000
  line_reset_interval: 100
remote_query:
  timeout: 30
  boot_controllers: []
EOF
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Wings configured${NC}"
    
    # Setup systemd service
    echo -e "${BLUE}[${ICON_ARROW}] Setting up systemd service...${NC}"
    cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=${WINGS_BIN} --config ${WINGS_DIR}/config.yml
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable wings.service > /dev/null 2>&1
    
    # Start Wings
    echo -e "${BLUE}[${ICON_ARROW}] Starting Wings...${NC}"
    systemctl start wings.service > /dev/null 2>&1 &
    spinner $!
    
    sleep 3
    
    if systemctl is-active --quiet wings; then
        echo -e "${GREEN}[${ICON_SUCCESS}] Wings started successfully${NC}"
    else
        echo -e "${YELLOW}[${ICON_WARNING}] Wings might need configuration before starting${NC}"
        echo -e "${YELLOW}Check status with: systemctl status wings${NC}"
    fi
    
    # Display completion
    clear
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${BOLD}  Wings Installation Completed!${NC}"
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}Wings Directory:${NC} ${WHITE}${WINGS_DIR}${NC}"
    echo -e "${CYAN}Configuration:${NC} ${WHITE}${WINGS_DIR}/config.yml${NC}"
    echo -e "${CYAN}Status:${NC} ${WHITE}systemctl status wings${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "${WHITE}1. Configure your node in the Pterodactyl Panel${NC}"
    echo -e "${WHITE}2. Copy the configuration to ${WINGS_DIR}/config.yml${NC}"
    echo -e "${WHITE}3. Restart Wings: systemctl restart wings${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run installation
install_wings
