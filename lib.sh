#!/bin/bash

# Default values for flags
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

BLUE='\033[34m'
GREEN='\033[1;32m'
RED='\033[1;31m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
NC='\033[0m'
RESET='\e[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $(date +'%H:%M:%S') ${WHITE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date +'%H:%M:%S') ${WHITE}$1${NC}"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date +'%H:%M:%S') ${WHITE}$1${NC}"
}

fatal() {
    echo -e "${RED}[FATAL]${NC} $(date +'%H:%M:%S') ${WHITE}$1${NC}"
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
install() {
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
    fi
    export PASS=$pass
    
    case "$action" in
        dbcreate)
            info "Creating database: $name"
            mariadb -e "CREATE DATABASE IF NOT EXISTS $name;"
            info "Database $name created."
            ;;

        dbdelete)
            info "Deleting database: $name"
            mariadb -e "DROP DATABASE IF EXISTS $name;"
            info "Database $name deleted."
            ;;

        usercreate)
            info "Creating user: $name"
            mariadb -e "CREATE USER IF NOT EXISTS '$name'@'localhost' IDENTIFIED BY '$pass';"
            info "User $name created."
            ;;

        userdelete)
            info "Deleting user: $name"
            mariadb -e "DROP USER IF EXISTS '$name'@'localhost';"
            info "User $name deleted."
            ;;

        *)
            fatal "Invalid action. Use dbcreate, dbdelete, usercreate, or userdelete."
            exit 1
            ;;
    esac
}
replace() {
    local file="$1"
    local search_string="$2"
    local replace_string="$3"

    if [ -f "$file" ]; then
        sed -i "s|$search_string|$replace_string|g" "$file"
        info "Replaced '$search_string' with '$replace_string' in $file."
    else
        error "File $file not found."
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

# Example usage:
#info "This is an informational message."
#warn "This is a warning message."
#error "This is an error message."
#fatal "This is a fatal error message."
