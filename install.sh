#!/bin/bash

# SubhanPlays Pterodactyl Installer - Main Menu
# Version: 1.0.0

# Source common functions
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check for remote execution
if [[ ! -f "$SCRIPT_DIR/panel.sh" ]] || [[ ! -f "$SCRIPT_DIR/wings.sh" ]]; then
    info "Downloading required files..."
    mkdir -p "$TMP_DIR"
    
    REPO_BASE="https://raw.githubusercontent.com/Subhanplays/csb-installer/main"
    
    for script in panel.sh wings.sh vps.sh change.sh update.sh remove.sh; do
        if [[ ! -f "$SCRIPT_DIR/$script" ]]; then
            download_file "$REPO_BASE/$script" "$TMP_DIR/$script"
            SCRIPT_DIR="$TMP_DIR"
        fi
    done
    
    # Also download common library
    mkdir -p "$TMP_DIR/lib"
    download_file "$REPO_BASE/lib/common.sh" "$TMP_DIR/lib/common.sh"
fi

# Display ASCII art header
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

# Full installation workflow
full_installation() {
    info "Starting full installation..."
    echo ""
    
    # VPS
    warning "VPS creation requires Docker and will run interactively"
    if confirm_action "Do you want to create a VPS container?" "YES"; then
        bash "$SCRIPT_DIR/vps.sh"
    fi
    
    # Panel
    info "Installing Pterodactyl Panel..."
    if ! bash "$SCRIPT_DIR/panel.sh"; then
        error "Panel installation failed"
        return 1
    fi
    
    # Wings
    info "Installing Pterodactyl Wings..."
    if ! bash "$SCRIPT_DIR/wings.sh"; then
        error "Wings installation failed"
        return 1
    fi
    
    success "Full installation completed!"
    pause_screen
}

# Main loop
main() {
    create_lock
    check_root
    
    while true; do
        display_menu
        
        local choice
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                info "Launching VPS creation..."
                bash "$SCRIPT_DIR/vps.sh"
                pause_screen
                ;;
            2)
                info "Installing Pterodactyl Panel..."
                if bash "$SCRIPT_DIR/panel.sh"; then
                    success "Panel installation completed"
                else
                    error "Panel installation failed"
                fi
                pause_screen
                ;;
            3)
                info "Installing Pterodactyl Wings..."
                if bash "$SCRIPT_DIR/wings.sh"; then
                    success "Wings installation completed"
                else
                    error "Wings installation failed"
                fi
                pause_screen
                ;;
            4)
                info "Opening configuration menu..."
                bash "$SCRIPT_DIR/change.sh"
                ;;
            5)
                info "Opening update menu..."
                bash "$SCRIPT_DIR/update.sh"
                pause_screen
                ;;
            6)
                info "Opening removal menu..."
                bash "$SCRIPT_DIR/remove.sh"
                pause_screen
                ;;
            7)
                full_installation
                ;;
            8)
                echo ""
                echo -e "${GREEN}${BOLD}Thank you for using SubhanPlays Pterodactyl Installer!${NC}"
                echo -e "${CYAN}Goodbye!${NC}"
                cleanup
                exit 0
                ;;
            *)
                error "Invalid option. Please choose 1-8"
                sleep 1
                ;;
        esac
    done
}

# Start main menu
main
