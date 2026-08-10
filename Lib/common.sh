#!/bin/bash

# SubhanPlays Pterodactyl Installer - Common Functions
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
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Icons
readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✖"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="→"
readonly ICON_STAR="★"
readonly ICON_CHECK="✔"
readonly ICON_CROSS="✘"

# Global variables
readonly TMP_DIR="/tmp/subhanplays-pterodactyl"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NO_ANIMATION=${NO_ANIMATION:-0}
INTERACTIVE=${INTERACTIVE:-1}

# Check if running in interactive terminal
if [[ ! -t 1 ]] || [[ ! -t 0 ]]; then
    INTERACTIVE=0
    NO_ANIMATION=1
fi

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Only remove temporary installer files
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    
    # Remove lock file if exists
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        rm -f "/tmp/subhanplays-installer.lock"
    fi
    
    exit $exit_code
}

# Set traps for cleanup
trap cleanup EXIT INT TERM

# Error handling
error_exit() {
    echo -e "${RED}[${ICON_ERROR}] ERROR: $1${NC}" >&2
    echo -e "${YELLOW}[${ICON_INFO}] What to check:${NC}" >&2
    echo -e "${WHITE}$2${NC}" >&2
    cleanup
    exit 1
}

# Display functions
info() {
    echo -e "${BLUE}[${ICON_INFO}]${NC} ${WHITE}$1${NC}"
}

success() {
    echo -e "${GREEN}[${ICON_SUCCESS}]${NC} ${WHITE}$1${NC}"
}

warning() {
    echo -e "${YELLOW}[${ICON_WARNING}]${NC} ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}[${ICON_ERROR}]${NC} ${WHITE}$1${NC}" >&2
}

header() {
    echo -e "${CYAN}${BOLD}$1${NC}"
}

# Animation functions
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    if [[ "$NO_ANIMATION" -eq 1 ]]; then
        wait $pid
        return $?
    fi
    
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

progress_bar() {
    local duration=$1
    local message=$2
    
    if [[ "$NO_ANIMATION" -eq 1 ]]; then
        sleep "$duration"
        echo -e "${GREEN}[${ICON_SUCCESS}]${NC} $message"
        return 0
    fi
    
    echo -ne "${BLUE}[${ICON_ARROW}]${NC} $message "
    
    local width=40
    local percent=0
    
    for ((i=0; i<=width; i++)); do
        percent=$((i * 100 / width))
        printf "\r${BLUE}[${ICON_ARROW}]${NC} $message ["
        for ((j=0; j<i; j++)); do printf "█"; done
        for ((j=i; j<width; j++)); do printf " "; done
        printf "] %3d%%" $percent
        sleep $(echo "scale=3; $duration / $width" | bc)
    done
    
    echo -e "\n${GREEN}[${ICON_SUCCESS}]${NC} $message - Complete"
}

pause_screen() {
    if [[ "$INTERACTIVE" -eq 1 ]]; then
        echo ""
        read -p "Press [Enter] to continue..."
    fi
}

# System detection
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
        VERSION_CODENAME=$VERSION_CODENAME
    else
        error_exit "Cannot detect OS" \
            "Make sure you're running a supported Debian/Ubuntu system"
    fi
    
    case $OS in
        debian|ubuntu)
            success "Detected: $OS $VERSION_ID ($VERSION_CODENAME)"
            ;;
        *)
            error_exit "Unsupported OS: $OS" \
                "This installer supports Debian and Ubuntu only"
            ;;
    esac
}

# Root check
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root" \
            "Please run: sudo bash $0"
    fi
    success "Running as root"
}

# Command checker
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        return 1
    fi
    return 0
}

# Package installer
install_packages() {
    local packages=("$@")
    
    info "Installing packages: ${packages[*]}"
    
    if check_command apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y > /dev/null 2>&1 &
        spinner $!
        
        apt-get install -y "${packages[@]}" > /dev/null 2>&1 &
        spinner $!
    else
        error_exit "Package manager not found" \
            "This script requires apt package manager"
    fi
    
    success "Packages installed successfully"
}

# Input validation
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email=$1
    if [[ ! $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

# Secure input
secure_read() {
    local prompt=$1
    local var_name=$2
    local value
    
    read -s -p "$prompt" value
    echo ""
    read -s -p "Confirm: " value_confirm
    echo ""
    
    if [[ "$value" != "$value_confirm" ]]; then
        error "Passwords do not match"
        return 1
    fi
    
    export "$var_name=$value"
    return 0
}

# Backup function
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        success "Backed up: $file -> $backup"
        echo "$backup"
    fi
}

# Service management
restart_service() {
    local service=$1
    systemctl restart "$service" > /dev/null 2>&1 &
    spinner $!
    
    if systemctl is-active --quiet "$service"; then
        success "Service $service restarted successfully"
        return 0
    else
        error "Failed to restart $service"
        return 1
    fi
}

# Configuration test
test_nginx_config() {
    nginx -t > /dev/null 2>&1
    return $?
}

# PHP version detection
detect_php_version() {
    local php_version=$(php -v 2>/dev/null | head -n1 | grep -oP 'PHP \K[0-9]+\.[0-9]+')
    if [[ -z "$php_version" ]]; then
        error_exit "PHP not found" \
            "Please install PHP first"
    fi
    echo "$php_version"
}

# Download with progress
download_file() {
    local url=$1
    local output=$2
    
    if [[ "$NO_ANIMATION" -eq 1 ]]; then
        wget -q -O "$output" "$url"
    else
        wget -q --show-progress -O "$output" "$url"
    fi
    
    return $?
}

# Check Docker
check_docker() {
    if ! check_command docker; then
        warning "Docker is not installed"
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        warning "Docker daemon is not running"
        systemctl start docker > /dev/null 2>&1
        sleep 2
        
        if ! docker info > /dev/null 2>&1; then
            error "Cannot start Docker daemon"
            return 1
        fi
    fi
    
    success "Docker is running"
    return 0
}

# Confirmation prompt
confirm_action() {
    local message=$1
    local required_response=${2:-"YES"}
    
    echo -e "${RED}${BOLD}WARNING!${NC}"
    echo -e "${YELLOW}$message${NC}"
    echo ""
    echo -e "${WHITE}Type ${BOLD}$required_response${NC}${WHITE} to continue:${NC}"
    read -r response
    
    if [[ "$response" != "$required_response" ]]; then
        error "Operation cancelled"
        return 1
    fi
    
    return 0
}

# Create lock file
create_lock() {
    if [[ -f "/tmp/subhanplays-installer.lock" ]]; then
        local pid=$(cat /tmp/subhanplays-installer.lock)
        if ps -p "$pid" > /dev/null 2>&1; then
            error_exit "Another instance is already running (PID: $pid)" \
                "Wait for the other instance to finish or remove /tmp/subhanplays-installer.lock"
        fi
    fi
    echo $$ > /tmp/subhanplays-installer.lock
}

# Database helper
create_mysql_db() {
    local db_name=$1
    local db_user=$2
    local db_pass=$3
    
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${db_name}\`;
CREATE USER IF NOT EXISTS '${db_user}'@'127.0.0.1' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
    
    if [[ $? -eq 0 ]]; then
        success "Database created successfully"
        return 0
    else
        error "Failed to create database"
        return 1
    fi
}
