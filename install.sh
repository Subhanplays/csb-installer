#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# SUBHANPLAYS PTERODACTYL INSTALLER
# Obsidian Terminal UI
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="$SCRIPT_DIR/vmdata"

# ============================================================
# COLORS
# ============================================================

RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'

# ============================================================
# TERMINAL
# ============================================================

hide_cursor() {
    printf '\033[?25l'
}

show_cursor() {
    printf '\033[?25h'
}

cleanup() {
    show_cursor
}

trap cleanup EXIT

trap 'echo; echo -e "${RED}${BOLD}✖ Installation stopped on line $LINENO.${RESET}"; show_cursor; exit 1' ERR

clear_screen() {
    clear 2>/dev/null || printf '\033c'
}

pause() {
    echo
    read -r -p "$(echo -e "${GRAY}Press Enter to continue...${RESET}")"
}

# ============================================================
# SYSTEM INFORMATION
# ============================================================

get_cpu_usage() {
    if command -v top >/dev/null 2>&1; then
        top -bn1 2>/dev/null |
            awk -F'id,' '/Cpu\(s\)/ {split($1,a,","); sub(/.* /,"",a[length(a)]); print int(100-a[length(a)])"%"; exit}'
    else
        echo "N/A"
    fi
}

get_ram_usage() {
    if command -v free >/dev/null 2>&1; then
        free | awk '/Mem:/ {printf "%d%%", ($3/$2)*100}'
    else
        echo "N/A"
    fi
}

get_disk_usage() {
    df -h / 2>/dev/null | awk 'NR==2 {print $5}'
}

get_hostname() {
    hostname 2>/dev/null || echo "unknown"
}

get_uptime() {
    uptime -p 2>/dev/null | sed 's/^up //' || echo "unknown"
}

get_network_status() {
    if command -v curl >/dev/null 2>&1 &&
       curl -fsS --connect-timeout 2 https://1.1.1.1 >/dev/null 2>&1; then
        echo -e "${GREEN}● CONNECTED${RESET}"
    else
        echo -e "${RED}● OFFLINE${RESET}"
    fi
}

# ============================================================
# SMALL UI HELPERS
# ============================================================

line() {
    echo -e "${GRAY}──────────────────────────────────────────────────────────────────────────────${RESET}"
}

section() {
    echo
    echo -e "${WHITE}${BOLD} ◉ $1${RESET}"
}

success() {
    echo -e " ${GREEN}✓${RESET} $1"
}

error_msg() {
    echo -e " ${RED}✖${RESET} $1"
}

warning() {
    echo -e " ${YELLOW}⚠${RESET} $1"
}

info() {
    echo -e " ${CYAN}➜${RESET} $1"
}

# ============================================================
# TYPEWRITER
# ============================================================

type_text() {
    local text="$1"
    local delay="${2:-0.015}"
    local i
    local char

    for ((i=0; i<${#text}; i++)); do
        char="${text:i:1}"
        printf '%s' "$char"
        sleep "$delay"
    done

    echo
}

# ============================================================
# SPINNER
# ============================================================

spinner() {
    local message="$1"
    local duration="${2:-2}"

    local frames=(
        '⠋'
        '⠙'
        '⠹'
        '⠸'
        '⠼'
        '⠴'
        '⠦'
        '⠧'
        '⠇'
        '⠏'
    )

    local end=$((SECONDS + duration))
    local i=0

    hide_cursor

    while (( SECONDS < end )); do
        printf "\r${CYAN}${frames[i % ${#frames[@]}]}${RESET} ${message}   "
        i=$((i + 1))
        sleep 0.08
    done

    printf "\r\033[K"

    show_cursor
}

# ============================================================
# PROGRESS BAR
# ============================================================

progress_bar() {
    local message="$1"
    local width=34
    local i
    local filled
    local empty
    local percent

    hide_cursor

    for ((i=0; i<=width; i++)); do

        filled=$(printf '%*s' "$i" '' | tr ' ' '█')
        empty=$(printf '%*s' "$((width-i))" '' | tr ' ' '░')

        percent=$((i * 100 / width))

        printf "\r ${CYAN}${message}${RESET} [${GREEN}${filled}${GRAY}${empty}${RESET}] ${WHITE}%3d%%${RESET}" "$percent"

        sleep 0.025
    done

    printf "\n"

    show_cursor
}

# ============================================================
# MAIN LOGO
# ============================================================

logo() {

    echo -e "${CYAN}${BOLD}"

    cat <<'EOF'

███████╗██╗   ██╗██████╗ ██╗  ██╗ █████╗ ███╗   ██╗
██╔════╝██║   ██║██╔══██╗██║  ██║██╔══██╗████╗  ██║
███████╗██║   ██║██████╔╝███████║███████║██╔██╗ ██║
╚════██║██║   ██║██╔═══╝ ██╔══██║██╔══██║██║╚██╗██║
███████║╚██████╔╝██║     ██║  ██║██║  ██║██║ ╚████║
╚══════╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝

EOF

    echo -e "${RESET}"
}

# ============================================================
# HEADER
# ============================================================

header() {

    echo -e "${WHITE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║              SUBHANPLAYS — PTERODACTYL INSTALLER                         ║"
    echo "║              OBSIDIAN TERMINAL EDITION • v1.0                            ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo
    echo -e "${MAGENTA}${BOLD}              ★★★ PTERODACTYL DEPLOYMENT SYSTEM ★★★${RESET}"
    echo

    echo -e "${GRAY}◉ INSTALLER INFORMATION${RESET}"
    echo -e "${GRAY}├─ Hostname          :${RESET} ${WHITE}$(get_hostname)${RESET}"
    echo -e "${GRAY}├─ Uptime            :${RESET} ${WHITE}$(get_uptime)${RESET}"
    echo -e "${GRAY}├─ Installer         :${RESET} ${CYAN}SubhanPlays Pterodactyl${RESET}"
    echo -e "${GRAY}└─ Working Directory :${RESET} ${WHITE}$SCRIPT_DIR${RESET}"

    line
}

# ============================================================
# SYSTEM STATUS
# ============================================================

system_status() {

    local cpu
    local ram
    local disk
    local network

    cpu="$(get_cpu_usage)"
    ram="$(get_ram_usage)"
    disk="$(get_disk_usage)"
    network="$(get_network_status)"

    section "SYSTEM STATUS"

    echo
    echo -e "   ${WHITE}CPU Usage:${RESET}   ${CYAN}${cpu}${RESET}      ${WHITE}RAM Usage:${RESET}   ${CYAN}${ram}${RESET}"
    echo -e "   ${WHITE}Disk Usage:${RESET}  ${CYAN}${disk}${RESET}      ${WHITE}Network:${RESET}    ${network}"

    echo
}

# ============================================================
# ROOT
# ============================================================

need_root() {

    if [[ "${EUID}" -ne 0 ]]; then

        clear_screen

        echo
        echo -e "${YELLOW}${BOLD}Root privileges are required.${RESET}"
        echo

        spinner "Requesting root access" 2

        exec sudo su -c "bash '$SCRIPT_DIR/install.sh' $*"
    fi
}

# ============================================================
# DOCKER
# ============================================================

install_docker() {

    if command -v docker >/dev/null 2>&1; then
        success "Docker is already installed."
        return
    fi

    info "Docker was not detected."

    spinner "Preparing Docker installation" 2

    apt-get update -qq

    apt-get install -y -qq \
        ca-certificates \
        curl >/dev/null

    spinner "Downloading Docker installer" 2

    curl -fsSL https://get.docker.com/ |
        CHANNEL=stable bash >/dev/null 2>&1

    systemctl enable --now docker 2>/dev/null || true

    success "Docker installed successfully."
}

# ============================================================
# DEBIAN VPS
# ============================================================

debian_vps() {

    clear_screen
    logo
    header

    section "DEPLOYMENT CONFIGURATION"

    echo
    echo -e " ${GRAY}├─ RAM        :${RESET} ${WHITE}7900 MB${RESET}"
    echo -e " ${GRAY}├─ CPU        :${RESET} ${WHITE}3 Cores${RESET}"
    echo -e " ${GRAY}├─ Disk       :${RESET} ${WHITE}100G${RESET}"
    echo -e " ${GRAY}└─ Image      :${RESET} ${CYAN}nothingtheking/debian-vm${RESET}"

    echo

    read -r -p "$(echo -e "${CYAN}${BOLD}➜ Start Debian VPS? [Y/n]: ${RESET}")" answer

    answer="${answer:-Y}"

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then

        error_msg "Debian VPS setup was declined."

        echo
        warning "Continuing on the current system."

        sleep 1

        return
    fi

    echo

    install_docker

    mkdir -p "$VM_DIR"

    progress_bar "Preparing Debian VPS"

    spinner "Connecting to Debian VM" 2

    echo
    line

    echo -e "${GREEN}${BOLD}"
    echo " ◉ DEBIAN VPS UPLINK"
    echo -e "${RESET}"

    echo -e " ${GRAY}├─ RAM        :${RESET} ${WHITE}7900 MB${RESET}"
    echo -e " ${GRAY}├─ CPU        :${RESET} ${WHITE}3 Cores${RESET}"
    echo -e " ${GRAY}├─ Disk       :${RESET} ${WHITE}100G${RESET}"
    echo -e " ${GRAY}└─ Container  :${RESET} ${CYAN}nothingtheking/debian-vm${RESET}"

    line

    echo

    cd "$SCRIPT_DIR"

    docker run -it --rm \
        -v "$PWD/vmdata:/vmdata" \
        -e RAM=7900 \
        -e CPU=3 \
        -e DISK_SIZE=100G \
        nothingtheking/debian-vm

    echo

    success "Returned from Debian VPS."

    sleep 1
}

# ============================================================
# SCRIPT LAUNCHER
# ============================================================

run_script() {

    local script="$1"

    shift || true

    if [[ ! -f "$SCRIPT_DIR/$script" ]]; then

        error_msg "Missing script: $script"

        echo
        echo -e "${GRAY}Expected:${RESET} $SCRIPT_DIR/$script"

        pause

        return 1
    fi

    chmod +x "$SCRIPT_DIR/$script" 2>/dev/null || true

    echo

    spinner "Connecting to $script" 2

    echo

    bash "$SCRIPT_DIR/$script" "$@"
}

# ============================================================
# SERVICE STATUS
# ============================================================

service_status() {

    clear_screen
    logo
    header

    section "SERVICE STATUS"

    echo

    echo -e "${WHITE} NGINX${RESET}"

    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo -e " └─ Status: ${GREEN}● ACTIVE${RESET}"
    else
        echo -e " └─ Status: ${RED}● INACTIVE${RESET}"
    fi

    echo

    echo -e "${WHITE} PTERODACTYL QUEUE${RESET}"

    if systemctl is-active --quiet pteroq 2>/dev/null; then
        echo -e " └─ Status: ${GREEN}● ACTIVE${RESET}"
    else
        echo -e " └─ Status: ${RED}● INACTIVE${RESET}"
    fi

    echo

    echo -e "${WHITE} WINGS${RESET}"

    if systemctl is-active --quiet wings 2>/dev/null; then
        echo -e " └─ Status: ${GREEN}● ACTIVE${RESET}"
    else
        echo -e " └─ Status: ${RED}● INACTIVE${RESET}"
    fi

    echo

    line

    pause
}

# ============================================================
# MAIN MENU
# ============================================================

menu() {

    while true; do

        clear_screen

        logo
        header
        system_status

        section "DEPLOYMENT & SERVICES"

        echo
        echo -e " ${GRAY}├─${RESET} ${CYAN}[1]${RESET} ${GREEN}Pterodactyl Panel${RESET}       ${GRAY}├─${RESET} ${CYAN}[5]${RESET} ${MAGENTA}Panel Settings${RESET}"
        echo -e " ${GRAY}├─${RESET} ${CYAN}[2]${RESET} ${BLUE}Wings${RESET}                   ${GRAY}├─${RESET} ${CYAN}[6]${RESET} ${CYAN}System Status${RESET}"
        echo -e " ${GRAY}├─${RESET} ${CYAN}[3]${RESET} ${YELLOW}Update Panel + Wings${RESET}    ${GRAY}├─${RESET} ${CYAN}[7]${RESET} ${WHITE}Restart Services${RESET}"
        echo -e " ${GRAY}└─${RESET} ${CYAN}[4]${RESET} ${RED}Remove Panel / Wings${RESET}    ${GRAY}└─${RESET} ${CYAN}[8]${RESET} ${WHITE}Debian VPS${RESET}"

        echo

        section "MAINTENANCE & TOOLS"

        echo
        echo -e " ${GRAY}├─${RESET} ${CYAN}[9]${RESET} ${WHITE}Installer Diagnostics${RESET}"
        echo -e " ${GRAY}└─${RESET} ${RED}[0]${RESET} ${BOLD}SHUTDOWN INSTALLER${RESET}"

        echo

        line

        echo
        read -r -p "$(echo -e "${CYAN}${BOLD}➜ Enter Option (0-9): ${RESET}")" choice

        case "$choice" in

            1)

                clear_screen
                logo
                header

                echo
                echo -e "${GREEN}${BOLD}◉ PTERODACTYL PANEL DEPLOYMENT${RESET}"
                echo

                progress_bar "Initializing Panel installer"

                run_script panel.sh

                pause

                ;;

            2)

                clear_screen
                logo
                header

                echo
                echo -e "${BLUE}${BOLD}◉ WINGS DEPLOYMENT${RESET}"
                echo

                progress_bar "Initializing Wings installer"

                run_script wings.sh

                pause

                ;;

            3)

                clear_screen
                logo
                header

                echo
                echo -e "${YELLOW}${BOLD}◉ PANEL + WINGS UPDATE${RESET}"
                echo

                progress_bar "Initializing update process"

                run_script update.sh

                pause

                ;;

            4)

                clear_screen
                logo
                header

                echo
                echo -e "${RED}${BOLD}◉ PTERODACTYL REMOVAL${RESET}"
                echo

                warning "This operation may remove installed Pterodactyl components."

                echo

                read -r -p "$(echo -e "${RED}${BOLD}Continue? [y/N]: ${RESET}")" confirm

                if [[ "$confirm" =~ ^[Yy]$ ]]; then

                    progress_bar "Initializing removal manager"

                    run_script remove.sh

                else

                    warning "Removal cancelled."

                fi

                pause

                ;;

            5)

                clear_screen
                logo
                header

                echo
                echo -e "${MAGENTA}${BOLD}◉ PANEL SETTINGS${RESET}"
                echo

                progress_bar "Initializing settings manager"

                run_script change.sh

                pause

                ;;

            6)

                service_status

                ;;

            7)

                clear_screen
                logo
                header

                section "SERVICE RESTART"

                echo

                spinner "Restarting Nginx" 1
                systemctl restart nginx 2>/dev/null || true

                spinner "Restarting Pterodactyl Queue" 1
                systemctl restart pteroq 2>/dev/null || true

                spinner "Restarting Wings" 1
                systemctl restart wings 2>/dev/null || true

                echo

                success "Service restart sequence completed."

                pause

                ;;

            8)

                debian_vps

                pause

                ;;

            9)

                clear_screen
                logo
                header

                section "INSTALLER DIAGNOSTICS"

                echo

                echo -e " ${GRAY}├─ Bash Version :${RESET} ${WHITE}${BASH_VERSION}${RESET}"
                echo -e " ${GRAY}├─ Hostname     :${RESET} ${WHITE}$(get_hostname)${RESET}"
                echo -e " ${GRAY}├─ CPU Usage    :${RESET} ${CYAN}$(get_cpu_usage)${RESET}"
                echo -e " ${GRAY}├─ RAM Usage    :${RESET} ${CYAN}$(get_ram_usage)${RESET}"
                echo -e " ${GRAY}├─ Disk Usage   :${RESET} ${CYAN}$(get_disk_usage)${RESET}"
                echo -e " ${GRAY}├─ Docker       :${RESET} $(command -v docker >/dev/null 2>&1 && echo -e "${GREEN}INSTALLED${RESET}" || echo -e "${RED}NOT INSTALLED${RESET}")"
                echo -e " ${GRAY}└─ Network      :${RESET} $(get_network_status)"

                echo

                if [[ -f "$SCRIPT_DIR/panel.sh" ]]; then
                    success "panel.sh detected."
                else
                    error_msg "panel.sh missing."
                fi

                if [[ -f "$SCRIPT_DIR/wings.sh" ]]; then
                    success "wings.sh detected."
                else
                    error_msg "wings.sh missing."
                fi

                if [[ -f "$SCRIPT_DIR/change.sh" ]]; then
                    success "change.sh detected."
                else
                    warning "change.sh missing."
                fi

                if [[ -f "$SCRIPT_DIR/update.sh" ]]; then
                    success "update.sh detected."
                else
                    warning "update.sh missing."
                fi

                if [[ -f "$SCRIPT_DIR/remove.sh" ]]; then
                    success "remove.sh detected."
                else
                    warning "remove.sh missing."
                fi

                echo

                line

                pause

                ;;

            0)

                clear_screen

                echo

                spinner "Shutting down SubhanPlays Installer" 2

                echo

                echo -e "${GREEN}${BOLD}"
                echo "╔══════════════════════════════════════════════════════════════╗"
                echo "║        SUBHANPLAYS INSTALLER SHUTDOWN COMPLETE             ║"
                echo "╚══════════════════════════════════════════════════════════════╝"
                echo -e "${RESET}"

                echo

                exit 0

                ;;

            *)

                error_msg "Invalid option: $choice"
                sleep 1

                ;;

        esac

    done
}

# ============================================================
# STARTUP
# ============================================================

startup() {

    clear_screen

    hide_cursor

    echo

    logo

    echo
    echo -e "${CYAN}${BOLD}"

    type_text "Initializing SubhanPlays Pterodactyl Installer..." 0.018

    echo -e "${RESET}"

    sleep 0.3

    progress_bar "Loading installer modules"

    spinner "Checking environment" 2

    success "Installer modules loaded."

    spinner "Preparing deployment interface" 1

    echo

    show_cursor

    sleep 0.5
}

# ============================================================
# MAIN
# ============================================================

need_root "$@"

startup

debian_vps

menu
