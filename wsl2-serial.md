# Using USB Serial Devices in WSL2

This guide explains how to pass USB serial devices (such as USB-to-serial adapters) from Windows to WSL2 and how to ensure that the required Linux drivers are available and working inside the WSL2 kernel. This allows direct access to hardware from Linux tools running within WSL2 — ideal for embedded development, serial debugging, or any work involving devices like Arduinos, STM32 boards, or modems.

---

## Overview

WSL2 supports USB/IP for device passthrough starting with kernel version **5.10 or higher**. This mechanism lets you forward a USB device from Windows into WSL2, where it appears like any other physical device — as long as the Linux driver is available.

To get this working, you need two things:

1. **USB device passthrough using** `usbipd-win`
2. **A working kernel module (driver) inside WSL2 for your specific device**

If the driver is not built into your kernel, you can [compile and install it manually](./wsl2-kernel.md).

---

## 1. Pass USB Devices to WSL2

These steps are based on Microsoft’s official documentation:
🔗 [Microsoft Docs – Connect USB Devices to WSL](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

### 1.1 Setup on Windows

#### Update the WSL Kernel (Run in **PowerShell on Windows** — **Admin required**)

```powershell
wsl --shutdown
wsl --update
```

Then verify your kernel version **inside WSL**:

```bash
uname -r
```

Your kernel version must be **5.10 or newer**.

#### Install or Update `usbipd-win` (Run in **PowerShell on Windows** — **Admin required**)

This is the required user-space tool that enables USB device sharing from the Windows host into WSL2. It runs as a background service and provides the `usbipd` command.

If you already have `winget`, run:

```powershell
winget install --interactive --exact dorssel.usbipd-win
# or to update:
winget upgrade --interactive --exact dorssel.usbipd-win
```

If you **don’t have `winget`**, run the following in PowerShell:

```powershell
$pkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue
if (-not $pkg) {
  Write-Host "Installing App Installer (winget)..."
  Start-Process "https://www.microsoft.com/p/app-installer/9nblggh4nns1" -Wait
} else {
  Write-Host "Winget already installed."
}

winget install --interactive --exact dorssel.usbipd-win
```

> ℹ️ `usbipd-win` runs as a Windows service and enables USB sharing into WSL.

### 1.2 Attach the USB Device (Run in **PowerShell on Windows** — Admin required)

1. **List USB devices**:

   ```powershell
   usbipd list
   ```

2. **Bind** the desired device (e.g., bus ID `4-4`):

   ```powershell
   usbipd bind --busid 4-4
   ```

3. **Attach** it to WSL:

   ```powershell
   usbipd attach --wsl --busid 4-4
   ```

4. **Verify inside WSL**:

   ```bash
   lsusb
   ```

5. **Detach when done** (PowerShell):

   ```powershell
   usbipd detach --busid 4-4
   ```

---

## 2. Check or Enable Serial Drivers in WSL2

In some cases, a device will show up when running `lsusb` inside WSL2, but **no `/dev/ttyUSB*` device will be created**. This usually means the device is passed through correctly from Windows, but **the corresponding driver is missing** in the WSL2 Linux kernel. The following steps will help you verify driver availability and load it if possible.

### 2.1 Check Existing Driver Support

You can check which USB serial drivers are available in your WSL2 kernel using:

```bash
zgrep CONFIG_USB_SERIAL /proc/config.gz | grep -v '^#'
```

#### Example: FTDI

```bash
zgrep FTDI /proc/config.gz
```

Output:

```
CONFIG_USB_SERIAL_FTDI_SIO=m
# CONFIG_USB_FTDI_ELAN is not set
```

✅ This means the `ftdi_sio` driver is available as a loadable module.

#### Example: PL2303

```bash
zgrep -i pl2303 /proc/config.gz
```

Output:

```
# CONFIG_USB_SERIAL_PL2303 is not set
```

❌ This driver is missing — you'll need to [build it manually](./wsl2-kernel.md).

---

### 2.2 Load an Available Driver

If the driver is present, you can load it using:

```bash
sudo modprobe ftdi_sio  # or cp210x, ch341, etc.
lsmod | grep usbserial
```

Example output:

```
Module        Size   Used by
ftdi_sio      49152  0
cp210x        28672  0
ch341         20480  0
usbserial     36864  3 ftdi_sio,cp210x,ch341
```

---

## 3. Fixing Permissions

Even if the device appears (e.g. `/dev/ttyUSB0`), you may not be able to use it unless permissions are adjusted.

On most Linux systems, USB serial devices are assigned to the `dialout` group. Other types of devices (e.g., `/dev/hidraw*`, `/dev/i2c-*`) may require access via other groups such as `input`, `i2c`, or `gpio`. Adjust rules accordingly if you're working with non-serial USB devices.

In WSL2, device permissions are normally managed via `udevd`, which is **not running by default** unless `systemd` is enabled. As a result, udev rules may not apply unless you enable `systemd` or configure things manually.

### 3.1 Add User to `dialout` Group

Most USB serial devices are assigned to the `dialout` group:

```bash
ls -l /dev/ttyUSB*
```

Output:

```
crw-rw---- 1 root dialout 188, 0 May  3 18:24 /dev/ttyUSB0
```

To gain access:

```bash
sudo usermod -aG dialout $USER
```

Then restart WSL (PowerShell on Windows):

```powershell
wsl --shutdown
```

---

### 3.2 Generic udev Rule (All USB Serial Devices)

This rule allows all `/dev/ttyUSB*` devices to be accessible by users in the `dialout` group:

```bash
sudo nano /etc/udev/rules.d/99-usb-serial.rules
```

Paste:

```udev
SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", MODE="0660", GROUP="dialout", TAG+="uaccess"
```

Then reload rules:

```bash
sudo udevadm control --reload
sudo udevadm trigger
```

---

### 3.3 Automated Setup (Recommended)

To automate the entire permission setup process, use the script [`wsl-usb-serial-permissions.sh`](./wsl-usb-serial-permissions.sh):

```bash
./wsl-usb-serial-permissions.sh
```

This script will:

1. Create appropriate udev rules
2. Reload udev configuration
3. Add your user to the `dialout` group
4. Remind you to restart WSL

---

Once all steps are complete, you should be able to use serial devices such as `/dev/ttyUSB0` inside WSL2 just like on a regular Linux machine — with no need for root permissions.
