#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

PANEL_DIR="/var/www/pterodactyl"
ENV_FILE="$PANEL_DIR/.env"
NGINX_FILE="/etc/nginx/sites-available/pterodactyl.conf"

[[ $EUID -eq 0 ]] || {
    echo -e "${RED}Run this script as root.${RESET}"
    exit 1
}

if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Pterodactyl Panel was not found.${RESET}"
    echo "Expected: $ENV_FILE"
    exit 1
fi

ask() {
    local prompt="$1"
    local value
    read -r -p "$prompt" value
    printf '%s' "$value"
}

update_env() {
    local key="$1"
    local value="$2"

    if grep -qE "^${key}=" "$ENV_FILE"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

get_admin() {
    local email="$1"

    php artisan tinker --execute="
        \$u = App\\\\Models\\\\User::where('email', '$email')->first();
        if (!\$u) { echo 'NOT_FOUND'; exit; }
        echo \$u->id;
    " 2>/dev/null | tr -d '\r\n'
}

change_username_email() {
    local current_email new_username new_email user_id

    current_email="$(ask "Current admin email: ")"
    new_username="$(ask "New username: ")"
    new_email="$(ask "New email [${current_email}]: ")"
    new_email="${new_email:-$current_email}"

    [[ -n "$current_email" ]] || { echo -e "${RED}Email cannot be empty.${RESET}"; return; }
    [[ -n "$new_username" ]] || { echo -e "${RED}Username cannot be empty.${RESET}"; return; }

    user_id="$(get_admin "$current_email")"

    if [[ "$user_id" == "NOT_FOUND" || -z "$user_id" ]]; then
        echo -e "${RED}Admin account not found.${RESET}"
        return
    fi

    USER_ID="$user_id" NEW_USERNAME="$new_username" NEW_EMAIL="$new_email" \
    php artisan tinker --execute='
        $u = App\Models\User::findOrFail(getenv("USER_ID"));
        $u->username = getenv("NEW_USERNAME");
        $u->email = getenv("NEW_EMAIL");
        $u->save();
        echo "UPDATED";
    '

    echo
    echo -e "${GREEN}Username/email updated successfully.${RESET}"
}

change_password() {
    local email password password2 user_id

    email="$(ask "Admin email: ")"
    user_id="$(get_admin "$email")"

    if [[ "$user_id" == "NOT_FOUND" || -z "$user_id" ]]; then
        echo -e "${RED}Admin account not found.${RESET}"
        return
    fi

    while true; do
        read -r -s -p "New password: " password
        echo
        read -r -s -p "Confirm password: " password2
        echo

        if [[ "$password" != "$password2" ]]; then
            echo -e "${RED}Passwords do not match.${RESET}"
            continue
        fi

        if [[ ${#password} -lt 8 ]]; then
            echo -e "${RED}Password must be at least 8 characters.${RESET}"
            continue
        fi

        break
    done

    USER_ID="$user_id" NEW_PASSWORD="$password" \
    php artisan tinker --execute='
        $u = App\Models\User::findOrFail(getenv("USER_ID"));
        $u->password = Illuminate\Support\Facades\Hash::make(getenv("NEW_PASSWORD"));
        $u->save();
        echo "UPDATED";
    '

    echo
    echo -e "${GREEN}Password updated successfully.${RESET}"
}

change_domain() {
    local old_domain new_domain

    old_domain="$(grep -E '^server_name ' "$NGINX_FILE" 2>/dev/null | head -1 | sed -E 's/.*server_name[[:space:]]+([^;]+);.*/\1/' || true)"
    new_domain="$(ask "New panel domain: ")"

    if [[ ! "$new_domain" =~ ^[A-Za-z0-9.-]+$ ]]; then
        echo -e "${RED}Invalid domain.${RESET}"
        return
    fi

    update_env "APP_URL" "https://${new_domain}"

    if [[ -f "$NGINX_FILE" ]]; then
        sed -i -E "s/server_name[[:space:]]+[^;]+;/server_name ${new_domain};/" "$NGINX_FILE"

        if nginx -t; then
            systemctl reload nginx
        else
            echo -e "${RED}Nginx configuration test failed. Restoring domain setting is recommended.${RESET}"
            return 1
        fi
    fi

    cd "$PANEL_DIR"
    php artisan config:clear
    php artisan cache:clear 2>/dev/null || true

    echo
    echo -e "${GREEN}Domain changed successfully.${RESET}"
    [[ -n "$old_domain" ]] && echo "Old domain: $old_domain"
    echo "New domain: $new_domain"
    echo
    echo -e "${YELLOW}Important:${RESET} DNS for ${new_domain} must point to this server."
    echo "If you use HTTPS, issue/update the certificate with Certbot."
}

change_all() {
    change_username_email
    echo
    change_password
    echo
    change_domain
}

menu() {
    while true; do
        clear || true
        echo -e "${CYAN}${BOLD}"
        echo "╔══════════════════════════════════════════════╗"
        echo "║       PTERODACTYL ACCOUNT SETTINGS          ║"
        echo "╚══════════════════════════════════════════════╝"
        echo -e "${RESET}"
        echo -e "${CYAN}1)${RESET} Change username + email"
        echo -e "${CYAN}2)${RESET} Change password"
        echo -e "${CYAN}3)${RESET} Change domain"
        echo -e "${CYAN}4)${RESET} Change everything"
        echo -e "${CYAN}5)${RESET} Back"
        echo

        read -r -p "Select [1-5]: " choice

        case "$choice" in
            1) change_username_email ;;
            2) change_password ;;
            3) change_domain ;;
            4) change_all ;;
            5) exit 0 ;;
            *) echo -e "${RED}Invalid option.${RESET}" ;;
        esac

        echo
        read -r -p "Press Enter to continue..."
    done
}

cd "$PANEL_DIR"
menu
