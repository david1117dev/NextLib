#!/bin/bash

# NextLibV2 - the next library for bash



DEBUG=false
DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -D|--dir)
            DIR="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done
BLUE='\033[38;5;32;1m'
GREEN='\033[1;32m'
RED='\033[1;31m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
NC='\033[0m'
RESET='\e[0m'
if [ "$WATERMARK" != "false" ]; then
    echo -e "\033[1;32m-------------------------\033[0m"
    echo -e "\033[1;32m[LIB]\033[0m \033[1;32mPowered by \033[0;32mNextLib\033[0m"
    echo -e "\033[1;32m-------------------------\033[0m"
fi
log_info() {
    echo -e "${GREEN}[INFO]${NC} ${WHITE}$1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} ${WHITE}$1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ${WHITE}$1${NC}"
}

log_fatal() {
    echo -e "${RED}[FATAL]${NC} ${WHITE}$1${NC}"
}
runasroot() {
    if [[ $EUID -ne 0 ]]; then
        fatal "This script requires root privileges. Please run it as root or with sudo."
        exit 1
    fi
}

check_distribution() {
    supported_distributions=("$@")
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        for dist in "${supported_distributions[@]}"; do
            if [[ "$PRETTY_NAME" == *"$dist"* ]]; then
                return
            fi
        done
    fi
    fatal "This is an unsupported Linux distribution/version."
    exit 1
}
apt_install() {
    apt-get update -y > "$OUTPUT_TARGET"
    apt-get upgrade -y > "$OUTPUT_TARGET"
    local package_list="$1"  # Get the comma-separated package list as the first argument
    IFS=',' read -ra packages <<< "$package_list"  # Parse the list into an array

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "$package"; then
            info "Installing $package..."
            if apt-get install -y "$package" > "$OUTPUT_TARGET"; then
                info "$package is successfully installed."
            else
                error "Failed to install $package."
            fi
        else
            info "$package is already installed."
        fi
    done
}
mariadb_manage() {
    if ! dpkg -l | grep -q "mariadb-server"; then
            apt-get install -y "mariadb-server" > "$OUTPUT_TARGET"
    fi
    local action="$1"
    local name="$2"
    local pass="$3"
    if [ "$pass" = "random" ]; then
        pass=$(openssl rand -base64 12)
        warn "Generated random password: $pass"
        export PASS=$pass
    fi
    
    case "$action" in
        dbcreate)
            info "Creating database: $name"
            mariadb -e "DROP DATABASE IF EXISTS $name; CREATE DATABASE $name;"
            ;;

        dbdelete)
            info "Deleting database: $name"
            mariadb -e "DROP DATABASE IF EXISTS $name;"
            ;;

        usercreate)
            info "Creating user: $name"
            mariadb -e "DROP USER IF EXISTS '$name'@'127.0.0.1'; FLUSH PRIVILEGES; CREATE USER '$name'@'127.0.0.1' IDENTIFIED BY '$pass';"
            ;;

        userdelete)
            info "Deleting user: $name"
            mariadb -e "DROP USER IF EXISTS '$name'@'localhost';"
            ;;

        *)
            fatal "Invalid action. Use dbcreate, dbdelete, usercreate, or userdelete."
            exit 1
            ;;
    esac
}

question() {
    local question_text="$1"
    local response_var="$2"
    local validate_type="$3"
    local user_response

    while true; do
        echo -e "${BLUE}[QUESTION]${NC} ${WHITE}$question_text${NC}"
        if [ "$validate_type" == "password" ]; then
            read -s -p "Your answer: " user_response
        else
            read -p "Your answer: " user_response
        fi

        if [ -n "$validate_type" ]; then
            if [ "$validate_type" == "url" ]; then
                if [[ $user_response =~ ^(http:\/\/localhost|http:\/\/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|https?:\/\/(localhost|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]+))$ ]]; then
                    echo "Valid URL."
                    eval "$response_var=\"$user_response\""
                    break
                else
                    error "Invalid URL. Please try again."
                fi
            elif [ "$validate_type" == "email" ]; then
                if [[ $user_response =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
                    echo "Valid email."
                    eval "$response_var=\"$user_response\""
                    break
                else
                    error "Invalid email. Please try again."
                fi
            elif [ "$validate_type" == "password" ]; then
                echo  # Add a newline after the hidden password input
                eval "$response_var=\"$user_response\""
                break
            else
                echo "Validation type not supported."
                break
            fi
        else
            eval "$response_var=\"$user_response\""
            break
        fi
    done
}

replace() {
    local file="$1"
    local search_string="$2"
    local replace_string="$3"

    if [ -f "$file" ]; then
        # Use sed with double quotes to allow variable substitution
        sed -i "s|$search_string|$replace_string|g" "$file"
        info "Replaced '$search_string' with '$replace_string' in $file."
    else
        error "File $file not found."
    fi
}
manage_cron_job() {
    local action="$1"
    local cron_command="$2"

    if [ "$action" == "add" ]; then
        (crontab -l ; echo "$cron_command") | crontab -
        info "Added the following cron job: $cron_command"
    elif [ "$action" == "remove" ]; then
        crontab -l | grep -v "$cron_command" | crontab -
        info "Removed the cron job containing: $cron_command"
    else
        error "Invalid action. Use 'add' or 'remove'."
    fi
}
if [ "$DEBUG" = true ]; then
    info "Debug mode is enabled."
    OUTPUT_TARGET="/dev/stdin"
else
    OUTPUT_TARGET="/dev/null"
fi
if [ -n "$DIR" ]; then
    info "Directory set to: $DIR"
fi
