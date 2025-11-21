#!/usr/bin/env bash

# ==============================================================================
# Common Functions Library
# Shared utilities for all setup scripts
# ==============================================================================

LOGFILE="${LOGFILE:-$HOME/setup-error.log}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.config-backups/$(date +%Y%m%d-%H%M%S)}"
TMP_DIR="${TMP_DIR:-$(mktemp -d)}"

# Initialize log file
mkdir -p "$(dirname "$LOGFILE")"
if [ ! -f "$LOGFILE" ]; then
    echo "=== Setup started at $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOGFILE"
fi

# Cleanup trap
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# COLORS
# ==============================================================================

RESET="\033[0m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"

# ==============================================================================
# LOGGING FUNCTIONS
# ==============================================================================

log_error() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${RED}ERROR${RESET}: $1" \
        | tee -a "$LOGFILE" >&2
}

log_info() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${BLUE}INFO${RESET}: $1"
}

log_warning() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${YELLOW}WARNING${RESET}: $1" \
        | tee -a "$LOGFILE"
}

log_critical() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] ${MAGENTA}CRITICAL${RESET}: $1" \
        | tee -a "$LOGFILE" >&2
    exit 1
}

handle_error() {
    log_error "Command failed at line $1"
}

trap 'handle_error $LINENO' ERR

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

safe_append() {
    local file="$1"
    local content="$2"
    local marker="$3"
    
    if [ ! -f "$file" ]; then
        echo "$content" > "$file"
        return
    fi
    
    if ! grep -qF "$marker" "$file"; then
        echo "$content" >> "$file"
    fi
}

backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename "$file").bak"
        log_info "Backed up $file"
    fi
}

safe_download() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -fsSL --connect-timeout 10 "$url" -o "$output"; then
            return 0
        fi
        retry=$((retry + 1))
        log_warning "Download attempt $retry failed for $url"
        sleep 2
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

install_if_missing() {
    local packages=("$@")
    local to_install=()
    
    for pkg in "${packages[@]}"; do
        if ! package_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done
    
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing: ${to_install[*]}"
        if ! sudo dnf install -y "${to_install[@]}" 2>> "$LOGFILE"; then
            log_error "Failed to install: ${to_install[*]}"
            return 1
        fi
    fi
    return 0
}

install_critical() {
    local packages=("$@")
    if ! install_if_missing "${packages[@]}"; then
        log_critical "Critical package installation failed: ${packages[*]}"
    fi
}

# Load NVIDIA flag if it exists
if [ -f /tmp/setup-nvidia-flag ]; then
    source /tmp/setup-nvidia-flag
fi
