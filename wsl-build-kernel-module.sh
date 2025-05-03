#!/bin/bash
#
# WSL2 Kernel Module Builder for USB Serial Drivers
# -------------------------------------------------------------------------------------------------------
# This script automates cloning the WSL2 kernel source, configuring it,
# building one or more USB serial driver modules, and saving them to a
# persistent location for reuse.
#
# Author: Ruslan Ovsyannikov <rovsyannikov@gmail.com>
# License: MIT License (see LICENSE file or https://opensource.org/licenses/MIT)
#
# Usage:
#   ./wsl-build-kernel-module.sh [module1 module2 ...]
#
# Example:
#   ./wsl-build-kernel-module.sh pl2303 cp210x ftdi_sio
#
# If no module names are provided, it defaults to: pl2303
#
# The resulting .ko modules will be stored under:
#   /usr/local/lib/wsl-modules/<kernel-version>/
#


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

# Modules to build — passed as arguments or fallback to default
MODULES=("$@")
if [ ${#MODULES[@]} -eq 0 ]; then
    MODULES=(pl2303)
fi

# Configuration
MODULE_PATH="drivers/usb/serial"
KERNEL_VERSION="$(uname -r)"
KERNEL_TAG="linux-msft-wsl-${KERNEL_VERSION%%-*}"
SRC_REPO="https://github.com/microsoft/WSL2-Linux-Kernel.git"
SRC_DIR="WSL2-Linux-Kernel"
PERSIST_DIR="/usr/local/lib/wsl-modules/$KERNEL_VERSION"

echo "==============================================================================="
echo "  Building modules:        ${MODULES[*]}"
echo "  Kernel version:          $KERNEL_VERSION"
echo "  Source tag:              $KERNEL_TAG"
echo "  Persistent location:     $PERSIST_DIR"
echo "==============================================================================="

# Step 0: Install required build dependencies (only if missing)
echo "[INFO] Checking for required build dependencies..."
DEPS=(build-essential flex bison libssl-dev libelf-dev bc dwarves libncurses-dev)
MISSING_DEPS=()

for pkg in "${DEPS[@]}"; do
    dpkg -s "$pkg" &> /dev/null || MISSING_DEPS+=("$pkg")
done

if [ "${#MISSING_DEPS[@]}" -eq 0 ]; then
    echo "  [OK] All dependencies already installed."
else
    echo "  [INFO] Missing packages: ${MISSING_DEPS[*]}"
    echo "  [INFO] Installing missing packages with sudo..."
    sudo apt-get update -qq
    if ! sudo apt-get install -y "${MISSING_DEPS[@]}" > /tmp/module_build_deps.log 2>&1; then
        echo "[ERROR] Failed to install dependencies. See /tmp/module_build_deps.log"
        exit 1
    fi
fi

# Step 1: Prepare WSL2 kernel source
if [ ! -d "$SRC_DIR" ]; then
    run_with_spinner "Cloning WSL2 kernel source (tag: $KERNEL_TAG)" /tmp/module_git_clone.log \
        git clone --progress --depth 1 --branch "$KERNEL_TAG" --single-branch "$SRC_REPO" "$SRC_DIR"
    cd "$SRC_DIR"
else
    echo "[INFO] Using existing kernel source directory: $SRC_DIR"
    cd "$SRC_DIR"
    if ! git rev-parse "$KERNEL_TAG" >/dev/null 2>&1; then
        run_with_spinner "Fetching tag: $KERNEL_TAG" /tmp/module_git_fetch.log \
            git fetch --depth=1 origin tag "$KERNEL_TAG"
    fi
    run_with_spinner "Checking out tag: $KERNEL_TAG" /tmp/module_git_checkout.log \
        git checkout -f "$KERNEL_TAG"
fi

# Step 2: Clean any existing kernel build artifacts
run_with_spinner "Cleaning previous build artifacts (make mrproper)" /tmp/module_make_mrproper.log \
    make mrproper || echo "[WARN] make mrproper failed — continuing"

# Extract and prepare kernel config
echo "[INFO] Extracting kernel config from running system..."
if ! cp /proc/config.gz . || ! gunzip -f config.gz || ! mv -f config .config; then
    echo "[ERROR] Failed to extract or decompress kernel config"
    exit 1
fi
chmod ug+w .config

# Enable all requested modules in .config
echo "[INFO] Enabling selected USB serial drivers in kernel config..."
for mod in "${MODULES[@]}"; do
    CONFIG_LINE="CONFIG_USB_SERIAL_${mod^^}=m"
    if grep -q "^CONFIG_USB_SERIAL_${mod^^}=" .config; then
        sed -i "s/^CONFIG_USB_SERIAL_${mod^^}=.*/$CONFIG_LINE/" .config
    else
        echo "$CONFIG_LINE" >> .config
    fi
done

# Step 3: Prepare kernel build environment
run_with_spinner "Running make olddefconfig" /tmp/module_oldconfig.log \
    make olddefconfig

run_with_spinner "Running make modules_prepare" /tmp/module_prepare.log \
    make -j"$(nproc)" modules_prepare

# Step 4: Build all specified modules
run_with_spinner "Building selected modules" /tmp/module_build.log \
    make -j"$(nproc)" M="$MODULE_PATH" modules

# Step 5: Copy built modules to persistent location
echo "[INFO] Copying built modules to: $PERSIST_DIR"
sudo mkdir -p "$PERSIST_DIR"
for mod in "${MODULES[@]}"; do
    MODULE_KO="$MODULE_PATH/$mod.ko"
    if [ -f "$MODULE_KO" ]; then
        sudo cp -v "$MODULE_KO" "$PERSIST_DIR/"
    else
        echo "[WARN] Compiled module not found: $MODULE_KO"
    fi
done

echo "[INFO] Build complete. You can now run the restore script or reboot WSL2 to load the module(s)."
