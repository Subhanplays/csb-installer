#!/bin/bash

# SubhanPlays Pterodactyl Installer - Wings Installation
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Wings configuration
WINGS_DIR="/etc/pterodactyl"
WINGS_BIN="/usr/local/bin/wings"

install_wings() {
    clear
    header "PTERODACTYL WINGS INSTALLATION"
    echo ""
    
    check_root
    detect_os
    
    # Get panel URL
    while true; do
        read -p "Enter your Pterodactyl Panel URL (e.g., https://panel.example.com): " PANEL_URL
        if [[ "$PANEL_URL" =~ ^https?:// ]]; then
            break
        fi
        error "Invalid URL format. Must start with http:// or https://"
    done
    
    read -p "Enter node name: " NODE_NAME
    
    echo ""
    warning "IMPORTANT: You must create a node in the Pterodactyl Panel first!"
    echo -e "${WHITE}1. Go to Admin Panel -> Nodes -> Create New${NC}"
    echo -e "${WHITE}2. Configure the node and generate a configuration${NC}"
    echo -e "${WHITE}3. Copy the configuration command or token${NC}"
    echo ""
    
    read -p "Press Enter when ready..."
    
    # Install Docker
    install_docker
    
    # Install Wings dependencies
    install_dependencies
    
    # Install Wings
    install_wings_binary
    
    # Configure Wings
    configure_wings
    
    # Setup systemd service
    setup_systemd
    
    # Start Wings
    start_wings    
    display_completion
}

install_docker() {
    info "Checking Docker installation..."
    
    if check_docker; then
        return 0
    fi
    
    warning "Docker not found. Installing..."
    
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 &
    spinner $!
    
    systemctl start docker > /dev/null 2>&1
    systemctl enable docker > /dev/null 2>&1
    
    if check_docker; then
        success "Docker installed successfully"
    else
        error_exit "Docker installation failed" \
            "Please install Docker manually: https://docs.docker.com/engine/install/"
    fi
}

install_dependencies() {
    info "Installing Wings dependencies..."
    
    local deps=(
        curl
        wget
        tar
        unzip
    )
    
    install_packages "${deps[@]}"
}

install_wings_binary() {
    info "Installing Pterodactyl Wings..."
    
    # Download latest Wings binary
    local latest_wings=$(curl -s https://api.github.com/repos/pterodactyl/wings/releases/latest | \
        grep "browser_download_url.*linux_amd64" | cut -d'"' -f4)
    
    if [[ -f "$WINGS_BIN" ]]; then
        backup_file "$WINGS_BIN"
    fi
    
    download_file "$latest_wings" "$WINGS_BIN"
    chmod u+x "$WINGS_BIN"
    
    success "Wings binary installed"
}

configure_wings() {
    info "Configuring Wings..."
    
    # Create directories
    mkdir -p "$WINGS_DIR"
    mkdir -p /var/lib/pterodactyl/volumes
    
    # Create initial config
    cat > "$WINGS_DIR/config.yml" <<EOF
debug: false
app_name: "${NODE_NAME}"
uuid: "$(uuidgen || cat /proc/sys/kernel/random/uuid)"
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

    success "Wings configured"
    
    echo ""
    warning "IMPORTANT: You must now configure Wings with your node token"
    echo -e "${WHITE}1. Go to your Panel Admin area${NC}"
    echo -e "${WHITE}2. Navigate to Nodes -> Your Node -> Configuration${NC}"
    echo -e "${WHITE}3. Copy the configuration file content${NC}"
    echo -e "${WHITE}4. Paste it into: ${WINGS_DIR}/config.yml${NC}"
    echo ""
    echo -e "${CYAN}After configuring, restart Wings with:${NC}"
    echo -e "${WHITE}systemctl restart wings${NC}"
}

setup_systemd() {
    info "Setting up Wings systemd service..."
    
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
    
    success "Systemd service configured"
}

start_wings() {
    info "Starting Wings..."
    
    systemctl start wings.service > /dev/null 2>&1 &
    spinner $!
    
    sleep 3
    
    if systemctl is-active --quiet wings; then
        success "Wings started successfully"
    else
        warning "Wings might need configuration before starting"
        warning "Check status with: systemctl status wings"
    fi
}

display_completion() {
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
