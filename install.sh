#!/bin/bash

# ============================================================
#        PTERODACTYL PANEL + WINGS INSTALLER
#        Beautiful CLI Installer
# ============================================================

set -e

# -------------------- COLORS --------------------

RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

# -------------------- CONFIG --------------------

PTERO_INSTALLER="https://raw.githubusercontent.com/unnamed-boy07/pterodactyl/refs/heads/main/pterodactyl-cb"

VERSION="1.0.0"
AUTHOR="SubhanPlayz"

# -------------------- FUNCTIONS --------------------

clear_screen() {
    clear
}

banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║              PTERODACTYL INSTALLER                          ║"
    echo "║                                                              ║"
    echo "║              Panel • Wings • VM                              ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${DIM}                  Installer v${VERSION} • ${AUTHOR}${RESET}"
    echo
}

line() {
    echo -e "${DIM}──────────────────────────────────────────────────────────────${RESET}"
}

success() {
    echo -e "${GREEN}✔${RESET} $1"
}

error() {
    echo -e "${RED}✖${RESET} $1"
}

info() {
    echo -e "${CYAN}ℹ${RESET} $1"
}

warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

step() {
    echo
    echo -e "${MAGENTA}${BOLD}➜ $1${RESET}"
    line
}

# Animated spinner
spinner() {
    local pid=$1
    local message="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % 10 ))
        printf "\r${CYAN}%s${RESET} %s" "${spin:$i:1}" "$message"
        sleep 0.1
    done

    printf "\r"
}

# Animated command runner
run_with_animation() {
    local message="$1"
    shift

    "$@" >/tmp/ptero_installer.log 2>&1 &
    local pid=$!

    spinner "$pid" "$message"

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        success "$message"
    else
        error "$message"
        echo
        echo -e "${RED}Last output:${RESET}"
        tail -20 /tmp/ptero_installer.log || true
        exit $status
    fi
}

# Progress animation
progress() {
    local message="$1"

    echo -ne "${CYAN}${message}${RESET} "

    for i in {1..20}; do
        echo -ne "${GREEN}█${RESET}"
        sleep 0.03
    done

    echo -e " ${GREEN}DONE${RESET}"
}

# -------------------- ROOT CHECK --------------------

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script as root."
        echo
        echo "Example:"
        echo -e "${CYAN}sudo $0 panel${RESET}"
        exit 1
    fi
}

# -------------------- DEPENDENCIES --------------------

install_dependencies() {

    step "Checking system dependencies"

    export DEBIAN_FRONTEND=noninteractive

    run_with_animation \
        "Updating package lists..." \
        apt update -y

    run_with_animation \
        "Installing required packages..." \
        apt install -y curl ca-certificates git apt-transport-https

    # Docker check
    if ! command -v docker >/dev/null 2>&1; then

        info "Docker is not installed."
        echo

        run_with_animation \
            "Installing Docker..." \
            bash -c 'curl -fsSL https://get.docker.com | sh'

        systemctl enable docker >/dev/null 2>&1 || true
        systemctl start docker >/dev/null 2>&1 || true

        success "Docker installed."
    else
        success "Docker is already installed."
    fi

    # Docker Compose check
    if docker compose version >/dev/null 2>&1; then
        success "Docker Compose plugin detected."
    elif command -v docker-compose >/dev/null 2>&1; then
        success "docker-compose detected."
    else

        info "Docker Compose is not installed."

        run_with_animation \
            "Installing Docker Compose..." \
            apt install -y docker-compose-plugin

        success "Docker Compose installed."
    fi

    echo
}

# -------------------- PANEL --------------------

install_panel() {

    clear_screen
    banner

    step "Installing Pterodactyl Panel"

    progress "Preparing installation"

    install_dependencies

    echo
    info "Starting Pterodactyl installer..."
    echo

    bash <(curl -fsSL "$PTERO_INSTALLER")

    echo
    line
    success "Pterodactyl Panel installation completed!"
    line

    echo
    echo -e "${GREEN}${BOLD}Panel installation finished.${RESET}"
    echo
}

# -------------------- WINGS --------------------

install_wings() {

    clear_screen
    banner

    step "Installing Pterodactyl Wings"

    install_dependencies

    step "Installing sshx"

    if command -v sshx >/dev/null 2>&1; then
        success "sshx is already installed."
    else
        curl -sSf https://sshx.io/get | sh -s run || true
        success "sshx installation completed."
    fi

    step "Creating Wings directory"

    mkdir -p /root/pterodactyl/wings
    mkdir -p /etc/pterodactyl
    mkdir -p /var/lib/pterodactyl
    mkdir -p /var/log/pterodactyl
    mkdir -p /tmp/pterodactyl

    success "Directories created."

    cd /root/pterodactyl/wings

    step "Creating Docker Compose configuration"

    cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  wings:
    image: ghcr.io/pterodactyl/wings:v1.6.1
    restart: always

    networks:
      - wings0

    ports:
      - "8080:8080"
      - "2022:2022"
      - "443:443"

    tty: true

    environment:
      TZ: "UTC"
      WINGS_UID: 988
      WINGS_GID: 988
      WINGS_USERNAME: pterodactyl

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /var/lib/docker/containers/:/var/lib/docker/containers/
      - /etc/pterodactyl/:/etc/pterodactyl/
      - /var/lib/pterodactyl/:/var/lib/pterodactyl/
      - /var/log/pterodactyl/:/var/log/pterodactyl/
      - /tmp/pterodactyl/:/tmp/pterodactyl/
      - /etc/ssl/certs:/etc/ssl/certs:ro

networks:
  wings0:
    name: wings0
    driver: bridge

    ipam:
      config:
        - subnet: 172.21.0.0/16

    driver_opts:
      com.docker.network.bridge.name: wings0
EOF

    success "docker-compose.yml created."

    step "Starting Wings"

    if docker compose version >/dev/null 2>&1; then
        run_with_animation \
            "Starting Wings container..." \
            docker compose up -d
    else
        run_with_animation \
            "Starting Wings container..." \
            docker-compose up -d
    fi

    echo
    line
    echo -e "${GREEN}${BOLD}"
    echo "          ✓ WINGS INSTALLATION COMPLETE"
    echo -e "${RESET}"
    line

    echo
    echo -e "${CYAN}${BOLD}Next Steps:${RESET}"
    echo
    echo -e "${WHITE}1.${RESET} Create your Wings node inside Pterodactyl."
    echo -e "${WHITE}2.${RESET} Copy the generated Wings configuration."
    echo -e "${WHITE}3.${RESET} Save it here:"
    echo
    echo -e "   ${YELLOW}/etc/pterodactyl/config.yml${RESET}"
    echo
    echo -e "${WHITE}4.${RESET} Restart Wings:"
    echo
    echo -e "   ${CYAN}cd /root/pterodactyl/wings${RESET}"
    echo -e "   ${CYAN}docker compose up -d --force-recreate${RESET}"
    echo
    echo -e "${WHITE}5.${RESET} Check Wings:"
    echo
    echo -e "   ${CYAN}docker logs -f wings${RESET}"
    echo
}

# -------------------- VM --------------------

install_vm() {

    clear_screen
    banner

    step "Starting Debian VM"

    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        error "Docker is not installed."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        error "Docker daemon is not running."
        echo
        echo "Try:"
        echo -e "${CYAN}systemctl start docker${RESET}"
        exit 1
    fi

    # VM storage
    VM_DIR="$PWD/vmdata"

    mkdir -p "$VM_DIR"

    echo
    echo -e "${CYAN}${BOLD}VM Configuration${RESET}"
    line
    echo -e "  ${WHITE}RAM:${RESET}       7900 MB"
    echo -e "  ${WHITE}CPU:${RESET}       3 cores"
    echo -e "  ${WHITE}Disk:${RESET}      100 GB"
    echo -e "  ${WHITE}Storage:${RESET}   $VM_DIR"
    echo

    # Check whether image exists
    if ! docker image inspect nothingtheking/debian-vm >/dev/null 2>&1; then
        info "Downloading Debian VM image..."
        docker pull nothingtheking/debian-vm
        echo
        success "VM image downloaded."
    else
        success "Debian VM image already exists."
    fi

    echo
    step "Starting Debian VM"

    echo
    info "Starting VM..."
    echo

    docker run \
        --name debian-vm \
        --restart unless-stopped \
        -it \
        -v "$VM_DIR:/vmdata" \
        -e RAM=7900 \
        -e CPU=3 \
        -e DISK_SIZE=100G \
        nothingtheking/debian-vm

    EXIT_CODE=$?

    echo

    if [ "$EXIT_CODE" -eq 0 ]; then
        success "Debian VM stopped normally."
    else
        error "Debian VM exited with code $EXIT_CODE."
    fi

    echo
    echo -e "${CYAN}${BOLD}VM Commands${RESET}"
    line
    echo
    echo -e "${WHITE}Start:${RESET}"
    echo -e "  ${CYAN}docker start -ai debian-vm${RESET}"
    echo
    echo -e "${WHITE}Logs:${RESET}"
    echo -e "  ${CYAN}docker logs debian-vm${RESET}"
    echo
    echo -e "${WHITE}Status:${RESET}"
    echo -e "  ${CYAN}docker ps -a --filter name=debian-vm${RESET}"
    echo
}

# -------------------- MENU --------------------

menu() {

    while true; do

        clear_screen
        banner

        echo -e "${BOLD}${WHITE}Choose an installation option:${RESET}"
        echo

        echo -e "  ${CYAN}[1]${RESET} Install Pterodactyl Panel"
        echo -e "  ${CYAN}[2]${RESET} Install Wings"
        echo -e "  ${CYAN}[3]${RESET} Start Debian VM"
        echo -e "  ${CYAN}[4]${RESET} Install Panel + Wings"
        echo -e "  ${RED}[5]${RESET} Exit"

        echo
        line
        echo

        read -rp "$(echo -e "${MAGENTA}➜${RESET} Select an option: ")" choice

        case "$choice" in

            1)
                install_panel
                read -rp "Press Enter to continue..."
                ;;

            2)
                install_wings
                read -rp "Press Enter to continue..."
                ;;

            3)
                install_vm
                ;;

            4)
                install_panel
                install_wings
                read -rp "Press Enter to continue..."
                ;;

            5)
                echo
                echo -e "${GREEN}Thanks for using the installer!${RESET}"
                exit 0
                ;;

            *)
                error "Invalid option."
                sleep 1
                ;;

        esac

    done
}

# -------------------- MAIN --------------------

check_root

case "${1:-}" in

    panel)
        install_panel
        ;;

    wings)
        install_wings
        ;;

    vm)
        install_vm
        ;;

    all)
        install_panel
        install_wings
        ;;

    "")
        menu
        ;;

    *)
        clear_screen
        banner

        error "Unknown option: $1"

        echo
        echo -e "${BOLD}Usage:${RESET}"
        echo
        echo -e "  ${CYAN}sudo $0${RESET}              Interactive menu"
        echo -e "  ${CYAN}sudo $0 panel${RESET}       Install Panel"
        echo -e "  ${CYAN}sudo $0 wings${RESET}       Install Wings"
        echo -e "  ${CYAN}sudo $0 vm${RESET}          Start Debian VM"
        echo -e "  ${CYAN}sudo $0 all${RESET}         Install Panel + Wings"
        echo

        exit 1
        ;;

esac