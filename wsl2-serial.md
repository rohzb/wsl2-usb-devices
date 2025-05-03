# 🔌 Using USB Serial Devices in WSL2

This guide explains how to pass USB devices (such as USB-to-serial adapters) from Windows to WSL2 and how to ensure the correct drivers are available or built in your WSL2 kernel.

---

## 🧽 Overview

WSL2 supports USB/IP for device passthrough starting with kernel version **5.10 or higher**. To use devices like serial adapters (PL2303, FTDI, CH341, CP210x), you must:

1. Pass the device from Windows to WSL2 using `usbipd-win`
2. Ensure the appropriate driver is available inside the WSL2 kernel

If the driver is missing, you may need to [build it manually](./wsl2-kernel.md).

---

## 🧾 1. Pass USB Devices to WSL2

Refer to the official Microsoft guide:
🔗 [Microsoft Docs – Connect USB Devices to WSL](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

### 🛠️ 1.1 Setup on Windows

#### ✅ Update the WSL Kernel

Run the following from **PowerShell (Admin)**:

```powershell
wsl --shutdown
wsl --update
```

Ensure your kernel version is **≥ 5.10**:

```bash
uname -r
```

#### ✅ Install `usbipd-win`

Install via `winget`:

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

Or update it:

```powershell
winget upgrade --interactive --exact dorssel.usbipd-win
```

### 🔌 1.2 Attach the USB Device

1. **List USB devices** (from PowerShell):

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

4. **Verify in WSL**:

   ```bash
   lsusb
   ```

5. **Detach** when done:

   ```powershell
   usbipd detach --busid 4-4
   ```

---

## 🧹 2. Check or Enable Serial Drivers in WSL2

### 🔍 2.1 Check Existing Driver Support

Inspect your kernel’s configuration to check for serial drivers:

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

✅ `ftdi_sio` driver is available as a module.

#### Example: PL2303

```bash
zgrep -i pl2303 /proc/config.gz
```

Output:

```
# CONFIG_USB_SERIAL_PL2303 is not set
```

❌ Driver is not available — you must [build and install it manually](./wsl2-kernel.md).

---

### 🫩 2.2 Load an Available Driver

If the driver is available, you can load it:

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

## 🔐 3. Fixing Permissions

Even with the driver loaded, you might not be able to use the device (e.g. `/dev/ttyUSB0`) unless proper permissions are in place.

### 👥 3.1 Add User to `dialout` Group

Most USB serial devices are owned by the `dialout` group:

```bash
ls -l /dev/ttyUSB*
```

Output:

```
crw-rw---- 1 root dialout 188, 0 May  3 18:24 /dev/ttyUSB0
```

To fix access:

```bash
sudo usermod -aG dialout $USER
```

Then restart WSL:

```powershell
wsl --shutdown
```

---

### ⚙️ 3.2 Generic udev Rule (All USB Serial Devices)

To make access persistent and universal across all serial adapters:

```bash
sudo nano /etc/udev/rules.d/99-usb-serial.rules
```

Paste the following:

```udev
SUBSYSTEM=="tty", KERNEL=="ttyUSB[0-9]*", MODE="0660", GROUP="dialout", TAG+="uaccess"
```

Reload rules:

```bash
sudo udevadm control --reload
sudo udevadm trigger
```

---

### 🧐 3.3 Automated Setup of Permissions (Recommended)

Use the script [`wsl-usb-serial-permissions.sh`](./wsl-usb-serial-permissions.sh) to automate permission fixes.

Run it like this:

```bash
./wsl-usb-serial-permissions.sh
```

It will:

1. Create udev rules for `ttyUSB*`
2. Reload rules
3. Add your user to `dialout` (if not already in it)
4. Remind you to restart WSL

---

You’re now ready to use serial devices like `/dev/ttyUSB0` inside WSL2 without root access or permission errors.
