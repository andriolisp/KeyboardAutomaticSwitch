# Keyboard Layout Switch (Wayland friendly)

Switch your GNOME keyboard layout based on which keyboard you are typing on.

Examples  
- External keyboard like `MX KEYS B` → `us+intl`  
- Laptop keyboard → `gb+intl`  

On Wayland, GNOME uses one global layout. This tool flips that layout fast when your last keypress comes from a specific keyboard. It feels like per device switching while you stay on Wayland.

---

## Features

- Wayland friendly. No X11 needed  
- Switches on the last keypress source  
- Keeps both layouts visible in the GNOME menu. Active one is first  
- Systemd user service. Starts on login  
- Installer and uninstaller  
- Works with any XKB layout and variant. Example `us+intl`, `gb`, `de+nodeadkeys`

---

## Project structure

```
KeyboardLayoutSwitch/
├─ Makefile
├─ README.md
├─ LICENSE
├─ scripts/
│  ├─ install.sh
│  ├─ uninstall.sh
│  ├─ keyboard-layout-autoswitch.sh
│  └─ detect-devices.sh
├─ systemd/
│  └─ keyboard-layout-autoswitch.service
├─ config/
│  └─ config.env.example
```

---

## How it works

- Reads `/proc/bus/input/devices` and maps `eventX` to device names  
- Listens to all input devices through `libinput debug-events`  
- On each keypress it finds which keyboard sent it  
- If the active GNOME layout does not match the keyboard preference, it flips the global layout using `gsettings`

---

## Requirements

- Linux with systemd user services  
- GNOME desktop. We use `gsettings` keys under `org.gnome.desktop.input-sources`  
- Packages: `libinput-tools`, `gawk`, `python3`

The installer tries to install packages on Debian or Ubuntu or Fedora or Arch or openSUSE. If your distro is different, follow the messages printed by the installer.

### Security note

The script needs read access to input events. We grant your user passwordless sudo for this one command only:

```
<your-user> ALL=(root) NOPASSWD: /usr/bin/libinput debug-events *
```

The installer writes a minimal sudoers file under `/etc/sudoers.d/` and validates it with `visudo`.

---

## Quick start

```bash
git clone git@github.com:andriolisp/KeyboardAutomaticSwitch.git
cd KeyboardAutomaticSwitch

# Option A. Use Make
make install

# Option B. Run the installer directly
./scripts/install.sh
```

The installer will

1. Detect your laptop keyboard name and your current GNOME layout  
2. List keyboard like devices so you can choose the external one  
3. Ask the layouts you want. Defaults are your current layout and `us+intl`  
4. Write `~/.config/kb-autoswitch/config.env`  
5. Install and start the systemd user service

---

## Manage the service

```bash
make status          # show service status
make logs            # follow logs
make restart         # restart service
make enable          # enable and start
make disable         # disable and stop
make detect          # list detected keyboards
make config-show     # print current config
make check           # dependency check and GNOME check
```

---

## Uninstall

```bash
make uninstall
# or
./scripts/uninstall.sh
```

This will stop and disable the service. It removes the sudoers file and the files installed in your home paths. Your repo clone is not removed.

---

## Configuration

Edit

```
~/.config/kb-autoswitch/config.env
```

Example

```bash
EXTERNAL_NAME="MX KEYS B"
INTERNAL_NAME="AT Translated Set 2 keyboard"
EXTERNAL_LAYOUT="us+intl"
INTERNAL_LAYOUT="gb+intl"
SWITCH_COOLDOWN="0.25"
```

Then

```bash
make restart
```

Tips

- You can use any XKB layout and variant string that GNOME supports. Examples `us`, `us+intl`, `gb`, `de+nodeadkeys`, `fr`, `es`  
- `SWITCH_COOLDOWN` avoids rapid flapping when you type on both keyboards very fast

---

## Compatibility

- Supported. GNOME on Wayland with a single seat and systemd user services  
- Likely works. GNOME on Xorg. On Xorg you can also use per device XKB InputClass  
- Not supported. Non GNOME desktops that do not use `org.gnome.desktop.input-sources`, systems without systemd user services, headless TTY sessions

---

## Restrictions and known limits

- One global layout. GNOME Wayland keeps one layout for the session. We flip it fast, but it is still global  
- Needs sudo for input events. If you cannot allow the sudoers entry, the tool cannot work  
- More than two keyboards. The default config handles laptop plus one external keyboard. You can set different names in the config if you have a dock or KVM, but only two are acted on by default  
- Composite devices. Some keyboards expose many event nodes or get renamed by docks. Use `make detect` to copy the exact `N: Name="..."`  
- IMEs and complex input methods. We switch XKB layout and variant only. If you use IMEs like IBus engines for CJK, results can vary  
- Remote or VM sessions. Wayland forwarding, VNC or nested sessions may not expose correct device names  
- Top bar label. The panel label may not update right away or may show the first layout name. The active layout is the first entry in `gsettings get org.gnome.desktop.input-sources sources`  
- CPU and power. `libinput debug-events` is light, but it runs all the time. On most laptops the impact is very low

---

## Troubleshooting

- No switching
  - `make logs` and watch for lines like `Switch to us+intl`  
  - `make check` to verify packages and GNOME availability  
  - `make detect` to find exact device names. Copy them into the config  

- Permission error from libinput
  - Check sudoers file under `/etc/sudoers.d/` and validate with `sudo visudo -c`  
  - The path to `libinput` must match your system. We detect it in the installer

- Layout flips but characters do not match
  - Confirm the active layout tuple
  - Run `gsettings get org.gnome.desktop.input-sources sources`
  - Try a dead key test. `' then e` should produce `é` on `*+intl`

- Service not running
  - `make status`
  - `systemctl --user daemon-reload` then `make restart`

---

## Contributing

Issues and pull requests are welcome. Keep scripts POSIX friendly where possible. Test on at least one Debian/Ubuntu and one Fedora/Arch system if you change install steps.

---

## License

MIT. See `LICENSE`.