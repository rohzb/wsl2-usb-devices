#!/bin/bash
#
# WSL2 Kernel Module Restore
# ---------------------------
# This script restores previously built kernel modules for WSL2,
# places them in the correct location under /lib/modules/, refreshes
# the module dependency cache, and attempts to load each module.
#
# Author: Ruslan Ovsyannikov <rovsyannikov@gmail.com>
# License: MIT License (see LICENSE file or https://opensource.org/licenses/MIT)
#
# Usage:
#   sudo ./wsl-restore-kernel-modules.sh
#
# The resulting .ko files will be copied from:
#   /usr/local/lib/wsl-modules/<kernel-version>/
# to:
#   /lib/modules/<kernel-version>/extra/

set -euo pipefail

# Spinner + background command runner
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

# Relaunch as root if not already
if [ "$EUID" -ne 0 ]; then
    echo "[INFO] This script must be run as root. Re-running with sudo..."
    exec sudo "$0" "$@"
fi

# Detect kernel version and define paths
KERNEL="$(uname -r)"
SRC_DIR="/usr/local/lib/wsl-modules/$KERNEL"
DEST_DIR="/lib/modules/$KERNEL/extra"
FAILED_MODULES=()

# Abort if no saved modules found
if [ ! -d "$SRC_DIR" ]; then
    echo "[INFO] No modules found at $SRC_DIR. Skipping restore."
    exit 0
fi

# Summary output
echo "==============================================================================="
echo "  Restoring custom kernel modules"
echo "  Kernel: $KERNEL"
echo "  Source: $SRC_DIR"
echo "  Target: $DEST_DIR"
echo "==============================================================================="

mkdir -p "$DEST_DIR"

# Step 1: Copy .ko files using rsync
run_with_spinner \
    "Step 1: Copying kernel modules (only if newer or missing)" \
    /tmp/module_rsync.log \
    rsync -a --itemize-changes --include='*.ko' --exclude='*' "$SRC_DIR/" "$DEST_DIR/"

# Display updated files (if any)
if [ -s /tmp/module_rsync.log ]; then
    cat /tmp/module_rsync.log | sed 's/^/  [UPDATED] /'
else
    echo "  [SKIPPED] No changes detected."
fi

# Step 2: Refresh module dependency cache
run_with_spinner \
    "Step 2: Refreshing module dependency cache (this may take a few minutes)" \
    /tmp/module_depmod.log \
    depmod -A

# Step 3: Load each module
echo "[INFO] Step 3: Loading modules..."
for mod in "$DEST_DIR"/*.ko; do
    modname="$(basename "$mod" .ko)"
    printf "  [LOAD] %-30s ... " "$modname"

    ERROR_MSG=$(modprobe "$modname" 2>&1)
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        echo "OK"
    else
        echo "FAILED"
        echo "         → $ERROR_MSG"
        FAILED_MODULES+=("$modname: $ERROR_MSG")
    fi
done

# Final report
echo "==============================================================================="
if [ "${#FAILED_MODULES[@]}" -gt 0 ]; then
    echo "[WARN] Some modules failed to load:"
    for fail in "${FAILED_MODULES[@]}"; do
        echo "  - $fail"
    done
    exit 1
else
    echo "[INFO] All modules loaded successfully."
    exit 0
fi
