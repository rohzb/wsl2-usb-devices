#!/bin/bash
#
# WSL2 Full Setup Script for USB Serial Devices
# ------------------------------------------------------------------------------------
# This script runs all helper scripts in order to:
# 1. Build missing kernel modules
# 2. Restore them into the running kernel
# 3. Configure WSL boot settings
# 4. Set up device permissions
#
# Author: Ruslan Ovsyannikov
# License: MIT License (see LICENSE or https://opensource.org/licenses/MIT)
#
# Usage:
#   sudo ./wsl-setup-all.sh

set -euo pipefail

# Relaunch as root if not already
if [ "$EUID" -ne 0 ]; then
    echo "[INFO] This script must be run as root. Re-running with sudo..."
    exec sudo "$0" "$@"
fi

log_header() {
    echo
    echo "==============================================================================="
    echo " STEP: $1"
    echo "==============================================================================="
}

log_footer() {
    echo "-------------------------------------------------------------------------------"
    echo
}

# Step 1: Build missing kernel modules
log_header "Building missing kernel modules"
./wsl-build-kernel-module.sh
log_footer

# Step 2: Restore modules into the current kernel
log_header "Restoring kernel modules into the running kernel"
./wsl-restore-kernel-modules.sh
log_footer

# Step 3: Configure WSL boot-time setup
log_header "Configuring WSL to restore modules and enable systemd"
./wsl-boot-config.sh
log_footer

# Step 4: Set up permissions for USB serial devices
log_header "Setting up udev rules and group permissions"
./wsl-usb-serial-permissions.sh
log_footer

echo "[INFO] ✅ All setup steps complete."
echo "[INFO] Run 'wsl --shutdown' from Windows PowerShell to apply changes."
