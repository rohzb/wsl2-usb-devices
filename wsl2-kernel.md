# Serial devices in WSL2

This repository documents how to use USB serial devices inside WSL2 on a Windows host. It's aimed at developers working with hardware like Arduinos, microcontrollers, embedded systems, and other serial-based devices. Many open-source tools for these platforms run better under Linux, so using them in WSL2 can be a good compromise between Linux flexibility and Windows convenience.

WSL2 makes it possible to use Linux-based tools directly on a Windows machine, but getting USB serial devices to work properly takes a bit of setup.

This setup is based on Ubuntu running in WSL2. Other distros should work too, but you may need to adjust package names or config paths.

---

## What's in this repo

* [`wsl2-serial.md`](./wsl2-serial.md)
  How to attach USB serial devices from Windows into WSL2 and make them accessible under `/dev/ttyUSB*`.

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
  Script that sets up udev rules and user permissions so serial devices are usable without root.

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

This behavior is a limitation of how WSL2 mounts and initializes its root filesystem and kernel image.

To work around this, this repo uses a dedicated toolset that:

* Stores built modules in a persistent directory: `/usr/local/lib/wsl-modules/<kernel>/`
* Automatically restores and loads them at WSL startup using a boot hook

---

## 💪 Setup Sequence (Recommended Order)

If your USB serial driver is missing, follow these steps:

### 1. Build the missing module(s)

This step compiles the driver source code into a kernel module compatible with your current WSL2 kernel version.

```bash
./wsl-build-kernel-module.sh pl2303
```

To build multiple at once:

```bash
./wsl-build-kernel-module.sh pl2303 cp210x ftdi_sio
```

The built modules will be stored in:

```
/usr/local/lib/wsl-modules/<your-kernel-version>/
```

This location is persistent across reboots.

---

### 2. Restore the module(s) into the running kernel

This step installs the previously built modules into the active kernel's module directory and makes them immediately usable.

```bash
sudo ./wsl-restore-kernel-modules.sh
```

This places them into `/lib/modules/<kernel>/extra/` and uses `depmod` + `modprobe` to register and load them.

---

### 3. Configure WSL to apply this on every boot (recommended)

Since WSL discards changes to `/lib/modules/` on shutdown, we use this script to automate the restore process every time WSL starts. It also optionally enables `systemd`, which is useful for device permissions and udev handling.

```bash
sudo ./wsl-boot-config.sh
```

You can also toggle each option individually:

```bash
sudo ./wsl-boot-config.sh --systemd on --restore off
```

This script modifies `/etc/wsl.conf` and is safe to run repeatedly.

---

### 4. Fix USB device permissions

To ensure `/dev/ttyUSB*` devices are usable without `sudo`, set up proper group permissions and udev rules:

```bash
./wsl-usb-serial-permissions.sh
```

This script:

* Adds a `udev` rule for `/dev/ttyUSB*`
* Ensures your user is part of the `dialout` group
* Triggers `udevadm` to reload and apply changes

Afterward, shut down and restart WSL:

```powershell
wsl --shutdown
```

---

### 5. Done! Check that your device appears

```bash
ls /dev/ttyUSB*
```

You should now see your serial device without needing root access.

---

## Contributions

Contributions or fixes are welcome. If you've improved compatibility for other devices or distributions, feel free to open a PR or file an issue.
