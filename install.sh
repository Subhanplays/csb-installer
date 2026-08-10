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

# GitHub raw URLs
readonly GITHUB_BASE="https://raw.githubusercontent.com/Subhanplays/csb-installer/main"
readonly TMP_DIR="/tmp/subhanplays-pterodactyl"

# Cleanup function
cleanup() {
    local exit_code=$?
    echo -e "${BLUE}[${ICON_INFO}] Cleaning up temporary files...${NC}"
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
        echo -e "${GREEN}[${ICON_SUCCESS}] Removed temporary directory${NC}"
    fi
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        rm -f "/tmp/subhanplays-installer.lock"
        echo -e "${GREEN}[${ICON_SUCCESS}] Removed lock file${NC}"
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
    echo -e "${GREEN}[${ICON_SUCCESS}] Running as root${NC}"
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

# Execute script directly from GitHub
run_script_from_github() {
    local script_name=$1
    local script_url="${GITHUB_BASE}/${script_name}"
    
    echo -e "${BLUE}[${ICON_INFO}] Fetching and executing ${script_name}...${NC}"
    echo -e "${WHITE}Source: ${script_url}${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Execute directly from GitHub
    bash <(curl -fsSL "$script_url")
    local exit_code=$?
    
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}[${ICON_SUCCESS}] ${script_name} completed successfully${NC}"
    else
        echo -e "${YELLOW}[${ICON_WARNING}] ${script_name} completed with exit code ${exit_code}${NC}"
    fi
    
    return $exit_code
}

# Check system requirements
check_requirements() {
    echo -e "${BLUE}[${ICON_INFO}] Checking system requirements...${NC}"
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        echo -e "${YELLOW}[${ICON_WARNING}] curl is required. Installing...${NC}"
        apt-get update -y > /dev/null 2>&1
        apt-get install -y curl > /dev/null 2>&1
        echo -e "${GREEN}[${ICON_SUCCESS}] curl installed${NC}"
    else
        echo -e "${GREEN}[${ICON_SUCCESS}] curl is available${NC}"
    fi
    
    # Check for bash
    if ! command -v bash &> /dev/null; then
        echo -e "${RED}[${ICON_ERROR}] bash is required${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[${ICON_SUCCESS}] All requirements satisfied${NC}"
    echo ""
}

# Full installation workflow
full_installation() {
    echo -e "${BLUE}[${ICON_INFO}] Starting full installation...${NC}"
    echo ""
    
    # Ask for VPS creation
    echo -e "${YELLOW}[${ICON_WARNING}] VPS creation requires Docker and will run interactively${NC}"
    read -p "Create Debian VPS? (y/n): " create_vps
    if [[ "$create_vps" =~ ^[Yy]$ ]]; then
        run_script_from_github "vps.sh"
        echo ""
    fi
    
    # Install Panel
    echo -e "${BLUE}[${ICON_INFO}] Installing Pterodactyl Panel...${NC}"
    run_script_from_github "panel.sh"
    echo ""
    
    # Install Wings
    echo -e "${BLUE}[${ICON_INFO}] Installing Pterodactyl Wings...${NC}"
    run_script_from_github "wings.sh"
    echo ""
    
    echo -e "${GREEN}${BOLD}[${ICON_SUCCESS}] Full installation completed!${NC}"
}

# Main loop
main() {
    # Check root first
    check_root
    
    # Check requirements
    check_requirements
    
    # Create lock file
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        local pid=$(cat /tmp/subhanplays-installer.lock)
        if ps -p "$pid" > /dev/null 2>&1; then
            echo -e "${RED}[${ICON_ERROR}] Another instance is already running (PID: $pid)${NC}"
            echo -e "${YELLOW}[${ICON_INFO}] Wait for it to finish or remove /tmp/subhanplays-installer.lock${NC}"
            exit 1
        fi
    fi
    echo $$ > /tmp/subhanplays-installer.lock
    
    # Verify GitHub connectivity
    echo -e "${BLUE}[${ICON_INFO}] Checking GitHub connectivity...${NC}"
    if curl -fsSL "${GITHUB_BASE}/install.sh" > /dev/null 2>&1; then
        echo -e "${GREEN}[${ICON_SUCCESS}] Connected to GitHub repository${NC}"
    else
        echo -e "${RED}[${ICON_ERROR}] Cannot connect to GitHub repository${NC}"
        echo -e "${YELLOW}[${ICON_INFO}] Please check your internet connection${NC}"
        echo -e "${YELLOW}[${ICON_INFO}] URL: ${GITHUB_BASE}${NC}"
        exit 1
    fi
    
    echo ""
    
    while true; do
        display_menu
        
        local choice
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                run_script_from_github "vps.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                run_script_from_github "panel.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                run_script_from_github "wings.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            4)
                run_script_from_github "change.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                run_script_from_github "update.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            6)
                run_script_from_github "remove.sh"
                echo ""
                read -p "Press Enter to continue..."
                ;;
            7)
                full_installation
                echo ""
                read -p "Press Enter to continue..."
                ;;
            8)
                echo ""
                echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}${BOLD}║  Thank you for using SubhanPlays Pterodactyl Installer! ║${NC}"
                echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${CYAN}Goodbye! 👋${NC}"
                echo ""
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
