# USB Device Access in WSL2

This repository documents how to use USB devices — especially USB-to-serial adapters — inside WSL2 on a Windows host. It is aimed at developers working with hardware like Arduinos, embedded boards, microcontrollers, and other serial-based or USB-connected equipment.

Many tools for such platforms work better under Linux, but WSL2 provides a practical middle ground between Linux development and Windows convenience.

This setup assumes Ubuntu in WSL2, though it can be adapted for other distros with minor changes.

---

## 🚦 Concept: Bridging USB Devices into WSL2

WSL2 does not have native access to USB devices. However, USB passthrough is possible using the [usbipd-win](https://github.com/dorssel/usbipd-win) project and USB/IP protocol.

The idea is:

```
  [USB Device]     →     [Windows Host + usbipd]     →     [WSL2 Kernel]     →     /dev/ttyUSB*
  (e.g. PL2303)          (bind & attach via CLI)         (Linux drivers handle device)
```

This repository provides tools to:

* Attach USB devices using `usbipd`
* Check kernel support for drivers
* Build and persist missing kernel modules (like `pl2303`)
* Configure permissions and startup behavior

To learn more about USB device passthrough and usbipd setup, see [`wsl2-serial.md`](./wsl2-serial.md).

---

## What's in this repo

* [`wsl2-serial.md`](./wsl2-serial.md)
  How to attach USB serial devices from Windows into WSL2 and make them accessible under `/dev/ttyUSB*`. Includes full `usbipd` setup.

* [`wsl2-kernel.md`](./wsl2-kernel.md)
  Instructions for checking which USB serial drivers are already in your WSL2 kernel, and how to rebuild the kernel module if something like `pl2303` is missing.

* [`wsl2-systemd.md`](./wsl2-systemd.md)
  Optional setup for enabling systemd in WSL2, which can help udev rules work correctly when devices are plugged in.

* [`wsl-build-kernel-module.sh`](./wsl-build-kernel-module.sh)
  Script to rebuild one or more USB serial kernel modules (e.g. `pl2303`, `cp210x`, `ftdi_sio`, etc.) from the WSL2 kernel source and store them persistently.

* [`wsl-restore-kernel-modules.sh`](./wsl-restore-kernel-modules.sh)
  Script to install and load the previously built kernel modules into `/lib/modules/<kernel>/extra/`, and update module dependencies.

* [`wsl-boot-config.sh`](./wsl-boot-config.sh)
  Tool to enable or disable WSL2 `systemd` support and automatically run the module restore script on boot, by editing `/etc/wsl.conf` safely and idempotently.

* [`wsl-usb-serial-permissions.sh`](./wsl-usb-serial-permissions.sh)
  Script to apply recommended `udev` rules and group membership fixes for using USB serial devices without root.

---

## Precompiled modules in WSL2

As of the time of writing, the default Microsoft-supplied WSL2 kernel includes many common USB serial drivers compiled as modules. You can check which are currently enabled with:

```bash
zgrep CONFIG_USB_SERIAL /proc/config.gz
```

Modules typically present in recent WSL2 kernels:

* `ftdi_sio` — FTDI-based serial converters
* `cp210x` — Silicon Labs USB-to-serial adapters
* `ch341` — WCH CH340/CH341 USB-serial chips
* `usbserial` — Generic USB serial core

### Missing modules

Some drivers — such as `pl2303` — may **not be included**, depending on the WSL2 kernel version. If the one you need is missing, you’ll need to build it manually using the provided scripts.

---

## Why modules must be restored manually

While WSL2 **does support loading custom kernel modules**, it does **not preserve them across restarts**. Any custom `.ko` file copied to `/lib/modules/` will be discarded the next time WSL2 is shut down or restarted.

This is due to how the WSL2 root filesystem is initialized from a compressed rootfs image.

This repo works around it by:

* Saving compiled modules into a persistent path: `/usr/local/lib/wsl-modules/<kernel>/`
* Restoring them on boot via a `wsl.conf` hook and helper script

---

## 💪 Setup Sequence (Recommended Order)

If your USB serial driver is missing, follow these steps:

### 1. Build the missing module(s)

This compiles the driver source into a kernel module for your WSL2 version.

```bash
./wsl-build-kernel-module.sh pl2303
```

To build multiple at once:

```bash
./wsl-build-kernel-module.sh pl2303 cp210x ftdi_sio
```

Modules are stored under:

```
/usr/local/lib/wsl-modules/<your-kernel-version>/
```

---

### 2. Restore the module(s) into the current kernel

This installs the module and makes it usable immediately:

```bash
sudo ./wsl-restore-kernel-modules.sh
```

This copies the modules to `/lib/modules/<kernel>/extra/`, runs `depmod`, and loads them with `modprobe`.

---

### 3. Set up WSL boot-time config

Since `/lib/modules` is volatile, run this to configure automatic restore + optional systemd enablement:

```bash
sudo ./wsl-boot-config.sh
```

You can control options:

```bash
sudo ./wsl-boot-config.sh --systemd on --restore off
```

---

### 4. Restart WSL to apply changes

```powershell
wsl --shutdown
```

After restarting, check for devices:

```bash
ls /dev/ttyUSB*
```

---

## Permissions

Even with a working driver, you might not be able to use the device unless proper permissions are in place.

To fix them automatically:

```bash
sudo ./wsl-usb-serial-permissions.sh
```

This adds udev rules, reloads them, and adds the current user to the `dialout` group.

---

## Contributions

Pull requests, improvements, and other hardware support welcome!
