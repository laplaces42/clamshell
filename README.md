# ClamshellToggle

A macOS menu bar app that keeps your MacBook running with the lid closed, so long-running jobs (builds, AI agent prompts, downloads) keep going while the laptop is shut. Opening the lid turns it off again.

The icon is an open laptop when idle and a closed laptop while clamshell mode is on.

## How it works

Closing the lid normally sleeps a MacBook unless it has power and an external display. The one setting that overrides this is:

```
sudo pmset -a disablesleep 1   # on
sudo pmset -a disablesleep 0   # off
```

ClamshellToggle wraps that in a toggle and adds safety nets. It does not use a mouse jiggler or `caffeinate`, neither of which stops lid-close sleep.

- **Lid open turns it off.** The app polls the lid state (`AppleClamshellState` in IOKit) and restores normal sleep when the lid goes from closed to open.
- **Locks on lid close** (optional, on by default), so the Mac is locked when you reopen it.
- **Cleanup on every exit path.** Sleep is restored on quit, on SIGTERM/SIGINT/SIGHUP, and on the next launch. While active, a small detached shell process restores sleep if the app crashes or is force-quit.
- **Safety stops** (all adjustable in the popover): battery at or below a floor (default 20%, on battery only), an auto-off timer (default 8 hours), and a stop if the Mac reaches a serious thermal state.
- **Launch at login** option.

## Requirements

- macOS 13 or later
- Swift toolchain (Xcode or Command Line Tools). No Xcode project is needed.

## Install

```
git clone https://github.com/laplaces42/clamshell.git
cd clamshell
./scripts/build-app.sh --install    # builds, ad-hoc signs, copies to ~/Applications
open ~/Applications/ClamshellToggle.app
```

On first run, click the menu bar icon and press **Set up…**. This asks for your admin password once and installs `/etc/sudoers.d/clamshelltoggle`, validated with `visudo`, which allows only:

```
<you> ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1
```

Nothing else runs as root.

## Usage

1. Click the icon and choose **Turn on clamshell mode**.
2. Close the lid. The Mac keeps running with the display off.
3. Open the lid. Clamshell mode turns off and normal sleep resumes.

## Caveats

- A closed lid traps heat. Use it on a desk with airflow, never in a bag.
- On battery it drains as usual. Plug in for long runs.
- Lock-on-close uses a private macOS call (`SACLockScreenImmediate`). If it is unavailable it falls back to display sleep, which only locks if your "require password after sleep" setting is immediate.
- The app is ad-hoc signed, so macOS may ask you to approve launch at login in System Settings.
- It can't wake a Mac that is already asleep. Turn it on before closing the lid.

## Troubleshooting

If the Mac ever won't sleep after a crash:

```
pmset -g | grep SleepDisabled
sudo pmset -a disablesleep 0
```

## Uninstall

```
sudo rm /etc/sudoers.d/clamshelltoggle
rm -rf ~/Applications/ClamshellToggle.app
```

## Project layout

- `Sources/ClamshellToggle/ClamshellController.swift`: state, polling, safety checks, watchdog
- `Sources/ClamshellToggle/System.swift`: `pmset`, lid, battery, lock screen, sudoers setup
- `Sources/ClamshellToggle/PopoverView.swift`: menu bar popover UI
- `Sources/ClamshellToggle/LaptopIcon.swift`: menu bar icon, drawn in code
- `scripts/build-app.sh`: builds and bundles the `.app`

## Ideas

- Turn on automatically while Claude Code is working, using hooks.
