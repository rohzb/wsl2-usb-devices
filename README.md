# USB Device Access in WSL2

Enable USB-to-serial and other USB device support in WSL2 using `usbipd-win` and optional custom kernel modules.

## Table of Contents

1. [Overview](#overview)
2. [Concept: Bridging USB Devices into WSL2](#concept-bridging-usb-devices-into-wsl2)
3. [Repository Contents](#repository-contents)
4. [Precompiled Modules in WSL2](#precompiled-modules-in-wsl2)
5. [Setup](#setup)

   * [Step 1: Windows Host Setup](#step-1-windows-host-setup-required-once)
   * [Step 2: WSL2 Setup](#step-2-wsl2-setup)
6. [Contributing](#contributing)
7. [License](#license)

## Overview

This repository provides everything needed to use USB devices — especially USB-to-serial adapters — inside WSL2. It's aimed at developers working with Arduinos, embedded boards, and other hardware platforms that expose serial interfaces over USB.

This setup assumes Ubuntu in WSL2, though other distros should work with minor changes.

## Concept: Bridging USB Devices into WSL2

WSL2 does not provide native access to USB devices. However, you can forward them using [`usbipd-win`](https://github.com/dorssel/usbipd-win) and the USB/IP protocol.

```
  [USB Device]     →     [Windows Host + usbipd]     →     [WSL2 Kernel]     →     /dev/ttyUSB*
  (e.g. PL2303)          (bind & attach via CLI)         (Linux drivers handle device)
```

This repository provides tools to:

* Attach USB devices via `usbipd`
* Check for driver availability in your WSL2 kernel
* Build missing kernel modules (e.g., `pl2303`)
* Restore them at boot
* Fix device permissions for user access
* Automate the entire process

See [`wsl2-serial.md`](./wsl2-serial.md) for a full walkthrough.

## Repository Contents

* [`wsl2-serial.md`](./wsl2-serial.md): Full guide for using USB serial devices with WSL2, including `usbipd` setup on Windows.
* [`wsl2-kernel.md`](./wsl2-kernel.md): Instructions for checking and compiling missing USB serial drivers (e.g. `pl2303`).
* [`wsl2-systemd.md`](./wsl2-systemd.md): Optional steps to enable systemd for improved udev support.
* `wsl-build-kernel-module.sh`: Build USB serial modules from the WSL2 kernel source.
* `wsl-restore-kernel-modules.sh`: Restore compiled modules into the active kernel.
* `wsl-boot-config.sh`: Configure `/etc/wsl.conf` to enable systemd and module restore at boot.
* `wsl-usb-serial-permissions.sh`: Apply udev rules and group membership for device access.
* `wsl-setup-all.sh`: Run all setup steps in sequence.

## Precompiled Modules in WSL2

WSL2 kernels include many common USB serial drivers as modules. To check which are present:

```bash
zgrep CONFIG_USB_SERIAL /proc/config.gz
```

### Typically included:

* `ftdi_sio` — FTDI-based serial converters
* `cp210x` — Silicon Labs USB-to-serial adapters
* `ch341` — CH340/CH341 USB-serial chips
* `usbserial` — Generic USB serial core

### May be missing:

* `pl2303` — Common adapter not always included

You can [build missing modules manually](./wsl2-kernel.md) if needed.

## Setup

### Step 1: Windows Host Setup (Required Once)

Install and configure `usbipd-win` on the Windows side to enable device forwarding.

Run the following in PowerShell (as Administrator):

```powershell
wsl --update
wsl --shutdown

winget install --interactive --exact dorssel.usbipd-win

usbipd list
usbipd bind --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

For full instructions and troubleshooting, see [wsl2-serial.md](./wsl2-serial.md).

### Step 2: WSL2 Setup

Once the USB device is attached, continue setup inside WSL2.

#### Option A: One-Line Setup

Run everything in one step:

```bash
sudo ./wsl-setup-all.sh
```

This script will:

* Build and install any missing modules
* Restore modules into the current kernel
* Configure systemd and boot behavior
* Fix device permissions via udev and group membership

#### Option B: Manual Setup

1. Build missing module(s) (e.g., for `pl2303` or others)

   ```bash
   ./wsl-build-kernel-module.sh pl2303
   ```

2. Restore module into the active kernel

   ```bash
   sudo ./wsl-restore-kernel-modules.sh
   ```

3. Enable boot-time restore and optional systemd

   ```bash
   sudo ./wsl-boot-config.sh
   ```

   Add `--systemd on` or `--restore off` as needed.

4. Fix USB serial permissions

   ```bash
   sudo ./wsl-usb-serial-permissions.sh
   ```

5. Restart WSL

   ```powershell
   wsl --shutdown
   ```

   After restart, your device should show up:

   ```bash
   ls /dev/ttyUSB*
   ```

## Contributing

Pull requests, improvements, and support for other USB device types are welcome.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for full terms.

* Free for personal and commercial use.
* Attribution to the author (Ruslan Ovsyannikov) is required in derivative works.
* Provided “as-is” with no warranty.
