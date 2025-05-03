#!/bin/bash
#
# wsl-boot-config.sh
# ---------------------------
# Enables/disables systemd support and automatic kernel module restore
# by updating /etc/wsl.conf and installing the restore helper if needed.
#
# Author: Ruslan Ovsyannikov <rovsyannikov@gmail.com>
# License: MIT License (see LICENSE file or https://opensource.org/licenses/MIT)
#
# Usage:
#   sudo ./wsl-boot-config.sh               # enable both systemd and restore (default)
#   sudo ./wsl-boot-config.sh --systemd off
#   sudo ./wsl-boot-config.sh --restore off
#   sudo ./wsl-boot-config.sh --systemd on --restore off

set -euo pipefail

WSL_CONF="/etc/wsl.conf"
RESTORE_SCRIPT_NAME="wsl-restore-kernel-modules.sh"
RESTORE_SCRIPT_PATH="/usr/local/bin/$RESTORE_SCRIPT_NAME"

# Default settings
ENABLE_SYSTEMD=true
ENABLE_RESTORE=true

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --systemd)
            shift
            [[ "${1:-}" == "off" ]] && ENABLE_SYSTEMD=false || ENABLE_SYSTEMD=true
            ;;
        --restore)
            shift
            [[ "${1:-}" == "off" ]] && ENABLE_RESTORE=false || ENABLE_RESTORE=true
            ;;
        *)
            echo "Usage: $0 [--systemd on|off] [--restore on|off]"
            exit 1
            ;;
    esac
    shift
done

# Ensure restore script is present if requested
deploy_restore_script() {
    if [ ! -f "$RESTORE_SCRIPT_PATH" ]; then
        echo -n "[INFO] Installing $RESTORE_SCRIPT_NAME ... "
        if [ -f "./$RESTORE_SCRIPT_NAME" ]; then
            sudo cp "./$RESTORE_SCRIPT_NAME" "$RESTORE_SCRIPT_PATH"
            sudo chmod +x "$RESTORE_SCRIPT_PATH"
            echo "DONE"
        else
            echo "FAILED"
            echo "[ERROR] $RESTORE_SCRIPT_NAME not found in current directory."
            exit 1
        fi
    else
        echo "[INFO] $RESTORE_SCRIPT_PATH already exists."
    fi
}

# Idempotent update of wsl.conf
update_wsl_conf() {
    echo "[INFO] Updating $WSL_CONF (systemd=$ENABLE_SYSTEMD, restore=$ENABLE_RESTORE)"
    sudo touch "$WSL_CONF"
    TMP_CONF=$(mktemp)
    cp "$WSL_CONF" "$TMP_CONF"

    # Remove old boot settings
    sed -i '/^\[boot\]/,/^\[/ s/^\s*systemd\s*=.*//g' "$TMP_CONF"
    sed -i '/^\[boot\]/,/^\[/ s/^\s*command\s*=.*//g' "$TMP_CONF"

    BOOT_PRESENT=false
    grep -q '^\[boot\]' "$TMP_CONF" && BOOT_PRESENT=true

    awk -v sysd="$ENABLE_SYSTEMD" -v restore="$ENABLE_RESTORE" -v path="$RESTORE_SCRIPT_PATH" '
    BEGIN { in_boot = 0; injected = 0 }
    /^\[boot\]/ {
        print; in_boot = 1
        if (sysd == "true")   print "systemd=true"
        if (restore == "true") print "command=" path
        injected = 1
        next
    }
    /^\[.*\]/ {
        in_boot = 0; print; next
    }
    { print }
    END {
        if (!injected) {
            print "[boot]"
            if (sysd == "true")   print "systemd=true"
            if (restore == "true") print "command=" path
        }
    }' "$TMP_CONF" > "$TMP_CONF.new"

    sudo mv "$TMP_CONF.new" "$WSL_CONF"
    rm -f "$TMP_CONF"
}

# Main execution
$ENABLE_RESTORE && deploy_restore_script
update_wsl_conf

echo "[INFO] Done. You can now run 'wsl --shutdown' to apply changes."