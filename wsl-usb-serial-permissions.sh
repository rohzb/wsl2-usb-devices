#!/bin/bash
#
# wsl-usb-serial-permissions.sh
# -------------------------------------------------------------------------------
# This script configures WSL2 to grant access to USB serial devices
# (e.g. ttyUSB*) by:
#   - Adding a udev rule to set permissions and group
#   - Adding the current user to the 'dialout' group
#   - Reloading udev
#
# Author: Ruslan Ovsyannikov <rovsyannikov@gmail.com>
# License: MIT License (see LICENSE file or https://opensource.org/licenses/MIT)
#
# Usage:
#   ./wsl-usb-serial-permissions.sh
#
# This only needs to be run once per distribution.
#

set -euo pipefail

# Spinner helper for long-running commands
run_with_spinner() {
    local description="$1"
    local log_file="$2"
    shift 2
    local cmd=("$@")

    echo -n "[INFO] $description ... "
    rm -f "$log_file"

    "${cmd[@]}" > "$log_file" 2>&1 &
    local pid=$!

    local spin='|/-\\'
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        printf "\b${spin:i++%${#spin}:1}"
        sleep 0.1
    done

    wait "$pid"
    local status=$?

    if [ $status -eq 0 ]; then
        echo -e "\bDONE"
    else
        echo -e "\bFAILED"
        echo "---------- $description output ----------"
        cat "$log_file"
        echo "--------------------------------------------------------------------------------"
        exit 1
    fi
}

UDEV_RULE_FILE="/etc/udev/rules.d/99-usb-serial.rules"
UDEV_CONTENT='SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", MODE="0660", GROUP="dialout", TAG+="uaccess"'

# Step 1: Create or overwrite udev rule
run_with_spinner "Writing udev rule for ttyUSB*" /tmp/udev_write.log \
    sudo bash -c "echo '$UDEV_CONTENT' > $UDEV_RULE_FILE"

# Step 2: Reload udev rules
run_with_spinner "Reloading udev rules" /tmp/udev_reload.log \
    sudo udevadm control --reload && sudo udevadm trigger

# Step 3: Add user to dialout group
if id -nG "$USER" | grep -qw dialout; then
    echo "[INFO] User '$USER' is already in the 'dialout' group."
else
    run_with_spinner "Adding user '$USER' to group 'dialout'" /tmp/group_add.log \
        sudo usermod -aG dialout "$USER"
    echo "[INFO] Please restart WSL (wsl --shutdown) for group changes to take effect."
fi

echo "==============================================================================="
echo "[INFO] USB serial access setup complete."
echo "[INFO] You can now use /dev/ttyUSB* devices without root."
echo "==============================================================================="
