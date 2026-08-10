#!/bin/bash

# SubhanPlays Pterodactyl Installer - VPS Creation
# Version: 1.0.0

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

create_vps() {
    clear
    header "CREATE DEBIAN VPS"
    echo ""
    
    check_root
    
    # Check Docker
    if ! check_docker; then
        warning "Docker is required for VPS creation"
        echo -n "Would you like to install Docker? (y/n): "
        read -r install_docker
        if [[ "$install_docker" =~ ^[Yy]$ ]]; then
            info "Installing Docker..."
            curl -fsSL https://get.docker.com | sh > /dev/null 2>&1 &
            spinner $!
            
            if ! check_docker; then
                error_exit "Docker installation failed" \
                    "Please install Docker manually"
            fi
        else
            error_exit "Docker is required for VPS creation" \
                "Install Docker and try again"
        fi
    fi
    
    # Create vmdata directory
    local VMDATA_DIR="$PWD/vmdata"
    if [[ ! -d "$VMDATA_DIR" ]]; then
        info "Creating VM data directory: $VMDATA_DIR"
        mkdir -p "$VMDATA_DIR"
        success "VM data directory created"
    fi
    
    # Display VPS configuration
    echo ""
    header "VPS CONFIGURATION"
    echo -e "${CYAN}RAM:${NC} ${WHITE}7900MB${NC}"
    echo -e "${CYAN}CPU:${NC} ${WHITE}3 cores${NC}"
    echo -e "${CYAN}Disk:${NC} ${WHITE}100GB${NC}"
    echo -e "${CYAN}Data Directory:${NC} ${WHITE}$VMDATA_DIR${NC}"
    echo ""
    
    warning "This will create a Docker container with Debian"
    echo -e "${WHITE}Press CTRL+C to stop the container at any time${NC}"
    echo -e "${WHITE}The container will run interactively${NC}"
    echo ""
    
    read -p "Press Enter to start the VPS..."
    
    # Run the container
    info "Starting Debian VPS container..."
    
    docker run -it --rm \
        -v "$VMDATA_DIR:/vmdata" \
        -e RAM=7900 \
        -e CPU=3 \
        -e DISK_SIZE=100G \
        nothingtheking/debian-vm
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 130 ]]; then
        success "VPS container stopped"
        info "VM data is preserved in: $VMDATA_DIR"
    else
        error "VPS container exited with code: $exit_code"
    fi
}

# Run VPS creation
create_vps
