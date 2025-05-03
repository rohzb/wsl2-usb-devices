# Enabling `systemd` and `udev` in WSL2

As of **Windows 11 build 22621 and later**, WSL2 supports running a real `systemd` init system. This enables many standard Linux services — such as `udevd`, `snapd`, and `journald` — that previously weren’t usable in WSL environments.

This guide explains how to enable `systemd` inside your WSL2 distribution, what to expect, how to verify that `udev` works, and how to automate the process using provided helper scripts.

---

## 🤖 Why Enable `systemd`?

With `systemd` active, your WSL2 distro behaves more like a full Linux environment. Benefits include:

* `udev` support for dynamic hardware events (e.g. USB devices)
* Background services using systemd units
* Compatibility with `snapd`, `journald`, `resolved`, etc.
* Closer parity with desktop/server Linux systems

This is especially useful when working with USB serial adapters (e.g. `/dev/ttyUSB0`) that rely on `udev` rules for permission fixes or user access.

---

## 🌀 Known Effects of Enabling `systemd`

Enabling `systemd` improves compatibility but changes WSL2 behavior:

### ⌛ Slower Startup

WSL takes longer to start, as systemd initializes background services.

### 📈 Increased Resource Usage

Memory and CPU usage may be slightly higher due to daemons like `journald`, `resolved`, etc.

### ⚠️ Some Units May Fail

WSL2 lacks full kernel and device access. Some services may fail or misbehave (e.g. requiring multicast networking).

### 📊 Logging Limitations

`journalctl` may have limited logs. Persistent logs require extra setup.

---

## ✨ How to Enable `systemd` in WSL2 (Manually)

1. **Edit `/etc/wsl.conf`**:

   ```ini
   [boot]
   systemd=true
   ```

2. **Shutdown WSL**:

   ```powershell
   wsl --shutdown
   ```

3. **Restart WSL** and verify:

   ```bash
   ps -p 1 -o comm=
   ```

   Expected output:

   ```
   systemd
   ```

4. **Check that `udevd` is active**:

   ```bash
   ps aux | grep '[u]devd'
   ```

   You should see:

   ```
   root       ... /lib/systemd/systemd-udevd
   ```

---

## 🌟 Recommended: Use Helper Script

Instead of editing `wsl.conf` manually, use the script provided in this repo:

```bash
sudo ./wsl-boot-config.sh
```

This will:

* Enable `systemd` in `/etc/wsl.conf`
* Optionally configure auto-restore of kernel modules on boot
* Safely install the restore helper script

You can control the options:

```bash
sudo ./wsl-boot-config.sh --systemd on --restore off
```

---

## 🔧 How to Test That `udev` Works

1. **Trigger `udev` manually**:

   ```bash
   sudo udevadm trigger --subsystem-match=tty
   ```

2. **Check the device node**:

   ```bash
   ls -l /dev/ttyUSB0
   ```

If permissions look like this, `udev` is working:

```bash
crw-rw---- 1 root dialout ... /dev/ttyUSB0
```

---

## ⚠️ Advanced: Start `udevd` Without systemd (Not Recommended)

```bash
sudo /lib/systemd/systemd-udevd &
sudo udevadm trigger --subsystem-match=tty
```

This is only for testing and won’t persist.

---

## 📄 Summary: Quick Checks

| Check               | Command                    | Expected Output                  |
| ------------------- | -------------------------- | -------------------------------- |
| Init system         | `ps -p 1 -o comm=`         | `systemd`                        |
| Is `udevd` running? | `ps aux \| grep '[u]devd'` | Line with `systemd-udevd`        |
| Device permissions  | `ls -l /dev/ttyUSB0`       | Group: `dialout` and mode `0660` |

---

## 📅 Final Notes

Enabling `systemd` brings WSL2 closer to real Linux behavior and enables tools and workflows that depend on device events, services, and background daemons.

If you're working with USB serial hardware, `systemd` + `udev` is strongly recommended for seamless behavior.

To automate both `systemd` and module restore config, just run:

```bash
sudo ./wsl-boot-config.sh
```

Then restart WSL:

```powershell
wsl --shutdown
```
