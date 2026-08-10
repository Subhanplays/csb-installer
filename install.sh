#!/bin/bash

# SubhanPlays Pterodactyl Installer - Main Menu
# Version: 1.0.0

set -euo pipefail

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"

# Determine script directory
if [[ -L "$0" ]] || [[ -f "$0" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
else
    # Running from curl pipe, download to temp directory
    SCRIPT_DIR="/tmp/subhanplays-pterodactyl-scripts"
    mkdir -p "$SCRIPT_DIR"
fi

readonly SCRIPT_DIR
readonly TMP_DIR="/tmp/subhanplays-pterodactyl"
readonly GITHUB_BASE="https://raw.githubusercontent.com/Subhanplays/csb-installer/main"

# Cleanup function
cleanup() {
    local exit_code=$?
    # Only cleanup temp download directory if we created it
    if [[ "$SCRIPT_DIR" == "/tmp/subhanplays-pterodactyl-scripts" ]]; then
        rm -rf "$SCRIPT_DIR"
    fi
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        rm -f "/tmp/subhanplays-installer.lock"
    fi
    exit $exit_code
}

# Set traps
trap cleanup EXIT INT TERM

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[${ICON_ERROR}] ERROR: This script must be run as root${NC}" >&2
        echo -e "${YELLOW}[${ICON_INFO}] Please run: sudo bash $0${NC}" >&2
        exit 1
    fi
}

# Download script if missing
download_script() {
    local script_name=$1
    
    # First check in current directory
    if [[ -f "$SCRIPT_DIR/$script_name" ]]; then
        return 0
    fi
    
    # Try to download from GitHub
    echo -e "${YELLOW}[${ICON_WARNING}] $script_name not found locally${NC}"
    echo -e "${BLUE}[${ICON_INFO}] Downloading from GitHub...${NC}"
    
    mkdir -p "$SCRIPT_DIR"
    
    if curl -fsSL "${GITHUB_BASE}/${script_name}" -o "$SCRIPT_DIR/$script_name" 2>/dev/null; then
        chmod +x "$SCRIPT_DIR/$script_name"
        echo -e "${GREEN}[${ICON_SUCCESS}] Downloaded $script_name${NC}"
        return 0
    else
        echo -e "${RED}[${ICON_ERROR}] Failed to download $script_name${NC}"
        echo -e "${YELLOW}[${ICON_INFO}] Please download all scripts from:${NC}"
        echo -e "${WHITE}${GITHUB_BASE}${NC}"
        return 1
    fi
}

# Display ASCII header
display_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
███████╗██╗   ██╗██████╗ ██╗  ██╗ █████╗ ███╗   ██╗
██╔════╝██║   ██║██╔══██╗██║  ██║██╔══██╗████╗  ██║
███████╗██║   ██║██████╔╝███████║███████║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║
███████║╚██████╔╝██║     ██║  ██║██║  ██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝
EOF
    echo -e "${NC}"
    echo -e "${MAGENTA}${BOLD}SUBHANPLAYS${NC}"
    echo -e "${CYAN}${BOLD}PTERODACTYL INSTALLER v1.0.0${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Display menu
display_menu() {
    display_header
    echo -e "${CYAN}Main Menu:${NC}"
    echo ""
    echo -e "${WHITE}[1]${NC} Create Debian VPS"
    echo -e "${WHITE}[2]${NC} Install Pterodactyl Panel"
    echo -e "${WHITE}[3]${NC} Install Pterodactyl Wings"
    echo -e "${WHITE}[4]${NC} Change Panel Domain / Admin Configuration"
    echo -e "${WHITE}[5]${NC} Update Panel & Wings"
    echo -e "${WHITE}[6]${NC} Remove Panel / Wings"
    echo -e "${WHITE}[7]${NC} Full Installation"
    echo -e "${WHITE}[8]${NC} Exit"
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Execute script with proper path
run_script() {
    local script_name=$1
    
    if ! download_script "$script_name"; then
        return 1
    fi
    
    bash "$SCRIPT_DIR/$script_name"
    return $?
}

# Main loop
main() {
    check_root
    
    # Create lock file
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        local pid=$(cat /tmp/subhanplays-installer.lock)
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${RED}[${ICON_ERROR}] Another instance is already running (PID: $pid)${NC}"
            exit 1
        fi
    fi
    echo $$ > /tmp/subhanplays-installer.lock
    
    while true; do
        display_menu
        
        local choice
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                echo -e "${BLUE}[${ICON_INFO}] Launching VPS creation...${NC}"
                run_script "vps.sh"
                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "${BLUE}[${ICON_INFO}] Installing Pterodactyl Panel...${NC}"
                run_script "panel.sh"
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "${BLUE}[${ICON_INFO}] Installing Pterodactyl Wings...${NC}"
                run_script "wings.sh"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "${BLUE}[${ICON_INFO}] Opening configuration menu...${NC}"
                run_script "change.sh"
                ;;
            5)
                echo -e "${BLUE}[${ICON_INFO}] Opening update menu...${NC}"
                run_script "update.sh"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo -e "${BLUE}[${ICON_INFO}] Opening removal menu...${NC}"
                run_script "remove.sh"
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "${BLUE}[${ICON_INFO}] Starting full installation...${NC}"
                echo -e "${YELLOW}[${ICON_WARNING}] VPS creation requires Docker and will run interactively${NC}"
                read -p "Create VPS first? (y/n): " create_vps
                if [[ "$create_vps" =~ ^[Yy]$ ]]; then
                    run_script "vps.sh"
                fi
                run_script "panel.sh"
                run_script "wings.sh"
                read -p "Press Enter to continue..."
                ;;
            8)
                echo ""
                echo -e "${GREEN}${BOLD}Thank you for using SubhanPlays Pterodactyl Installer!${NC}"
                echo -e "${CYAN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[${ICON_ERROR}] Invalid option. Please choose 1-8${NC}"
                sleep 1
                ;;
        esac
    done
}

# Start main menu
main
