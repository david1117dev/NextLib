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

# Define a function to check the distribution
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
    local package_list="$1"  # Get the comma-separated package list as the first argument
    IFS=',' read -ra packages <<< "$package_list"  # Parse the list into an array

    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "$package"; then
            info "Installing $package..."
            if apt-get install -y "$package"; then
                info "$package is successfully installed."
            else
                error "Failed to install $package."
            fi
        else
            info "$package is already installed."
        fi
    done
}
# Use the DEBUG and DIR flags within your script

if [ "$DEBUG" = true ]; then
    info "Debug mode is enabled."
    OUTPUT_TARGET="/dev/stdin"  # Output will be shown
else
    OUTPUT_TARGET="/dev/null"  # Output will be discarded
fi
echo ${OUTPUT_TARGET}
apt-get update > OUTPUT_TARGET
if [ -n "$DIR" ]; then
    info "Directory set to: $DIR"
fi

# Example usage:
info "This is an informational message."
warn "This is a warning message."
error "This is an error message."
fatal "This is a fatal error message."
