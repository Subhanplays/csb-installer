#!/bin/bash

# SubhanPlays Pterodactyl Installer - VPS Creation
# Version: 1.0.0

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[${ICON_ERROR}] This script must be run as root${NC}"
        exit 1
    fi
}

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
}

create_vps() {
    clear
    echo -e "${CYAN}${BOLD}CREATE DEBIAN VPS${NC}"
    echo ""
    
    check_root
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}[${ICON_WARNING}] Docker is required for VPS creation${NC}"
        read -p "Would you like to install Docker? (y/n): " install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}[${ICON_INFO}] Installing Docker...${NC}"
            curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 &
            spinner $!
        else
            echo -e "${RED}[${ICON_ERROR}] Docker is required for VPS creation${NC}"
            exit 1
        fi
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}[${ICON_ERROR}] Docker daemon is not running${NC}"
        systemctl start docker > /dev/null 2>&1
        sleep 2
        if ! docker info > /dev/null 2>&1; then
            echo -e "${RED}[${ICON_ERROR}] Cannot start Docker daemon${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}[${ICON_SUCCESS}] Docker is running${NC}"
    
    # Create vmdata directory
    local VMDATA_DIR="$PWD/vmdata"
    if [[ ! -d "$VMDATA_DIR" ]]; then
        echo -e "${BLUE}[${ICON_INFO}] Creating VM data directory: $VMDATA_DIR${NC}"
        mkdir -p "$VMDATA_DIR"
    fi
    
    # Display VPS configuration
    echo ""
    echo -e "${CYAN}${BOLD}VPS CONFIGURATION${NC}"
    echo -e "${CYAN}RAM:${NC} ${WHITE}7900MB${NC}"
    echo -e "${CYAN}CPU:${NC} ${WHITE}3 cores${NC}"
    echo -e "${CYAN}Disk:${NC} ${WHITE}100GB${NC}"
    echo -e "${CYAN}Data Directory:${NC} ${WHITE}$VMDATA_DIR${NC}"
    echo ""
    
    echo -e "${YELLOW}[${ICON_WARNING}] This will create a Docker container with Debian${NC}"
    echo -e "${WHITE}Press CTRL+C to stop the container at any time${NC}"
    echo -e "${WHITE}The container will run interactively${NC}"
    echo ""
    
    read -p "Press Enter to start the VPS..."
    
    # Run the container
    echo -e "${BLUE}[${ICON_INFO}] Starting Debian VPS container...${NC}"
    
    docker run -it --rm \
        -v "$VMDATA_DIR:/vmdata" \
        -e RAM=7900 \
        -e CPU=3 \
        -e DISK_SIZE=100G \
        nothingtheking/debian-vm
    
    echo -e "${GREEN}[${ICON_SUCCESS}] VPS container stopped${NC}"
    echo -e "${BLUE}[${ICON_INFO}] VM data is preserved in: $VMDATA_DIR${NC}"
}

create_vps
