<br><br><br>
<p align=center>
  <img src="assets/spacium.svg" alt="Spacium" width="478">
</p>
<br><br>

# Spacium

<p>
  <a href="https://github.com/irunatbullets/spacium/actions/workflows/update-image.yml"><img src="https://github.com/irunatbullets/spacium/actions/workflows/update-image.yml/badge.svg" alt="Update image"></a> <a href="https://github.com/irunatbullets/spacium"><img src="https://img.shields.io/github/last-commit/irunatbullets/spacium" alt="Last Commit"></a>
</p>

This custom **Bazzite** image is based on `bazzite-gnome`.

It swaps the GNOME session for **DMS (Dux Shell)** as the desktop shell, with
two Wayland compositors available: **Umbriel** and **Aqueous**. The login screen
is **DMS Greeter**, running on the Aqueous compositor.

My goal with this image is to offer a DMS-based desktop with gaming capabilities
(via Bazzite).

Feel free to suggest additional software - or just fork this repo and do
whatever you like.

To switch, run the following command from a terminal in any Universal Blue or
Fedora Atomic based install:

```
sudo bootc switch ghcr.io/irunatbullets/spacium
```

**Important Note:** After switching to this image the login will backup any
existing Umbriel configuration (`~/.config/umbriel`) and replace it with the
standard Spacium Umbriel config (which autostarts DMS). Updates will not
retrigger this event.

## What my selection of additional applications achieve

- **gnome-terminal** - the default terminal, opened with `Mod+Return` in Umbriel.
- **bluetui** - an application for configuring multiple Bluetooth receivers.

## Known issues and workarounds

### Where does DMS/Umbriel/Aqueous come from?

- **DMS (Dux Shell) 2.0** comes from the `avengemedia/dms-git` COPR, with
  `quickshell`, `dgop`, `matugen` and `dms-greeter-git` from
  `avengemedia/danklinux`. The new Dux Labs repositories are not complete for
  Fedora 44 yet, so the AvengeMedia channels are used.
- **Umbriel** and its portal come from the community
  [`c0mpile/builds`](https://copr.fedorainfracloud.org/coprs/c0mpile/builds/)
  COPR. Terra's `umbriel-nightly` is frozen at 2026-10-03 and its IPC cannot
  talk to the current DMS event stream.
- **Aqueous** is not packaged for Fedora, so it is compiled from source in a
  builder stage of the `Containerfile` and installed from a local RPM. Welcome
  is not staged: the Aqueous session preselects **DMS**
  (`/etc/xdg/aqueous/session.toml`), so it starts directly without Shelly.
  `Super+Return` opens `foot` under Aqueous.

### Why does the build replace Xwayland?

The packaged Umbriel depends on `xwayland-satellite`, which requires Fedora's
`xorg-x11-server-Xwayland`. Bazzite ships Terra's build of Xwayland, which
conflicts with Fedora's, so the build swaps Terra's Xwayland for Fedora's (the
same upstream version) using `dnf --allowerasing`. As a result
`xwayland-satellite` is installed even though upstream Umbriel now uses
wlroots' native Xwayland.

### Screen sharing

Umbriel uses **xdg-desktop-portal-umbriel** and Aqueous ships its own
`xdg-desktop-portal-aqueous`; both are installed and configured automatically.
If an application can't share the screen, make sure it is using the portal.

### DMS Greeter

The login screen is DMS Greeter running on Aqueous. Sync its theme from a
running DMS session with `dms-greeter sync`.

## Credits:

- https://bazzite.gg/
- https://duxlabs.dev/
- https://github.com/duxlabs-dev/dux-shell
- https://github.com/Seafoam-Labs/Aqueous
- https://github.com/noctalia-dev/umbriel
- https://tsuburaya-prod.com/ (for Ultraman, the inspiration behind the name of this image)
- https://zone108.main.jp/s/jp-005gontakana.php<br>FZゴンタかな is licensed under the [SIL Open Font License, Version 1.1](https://github.com/irunatbullets/spacium/blob/5ce3fb4974ead6809fc2b79f841c56f48572e577/assets/licenses/FZ%E3%82%B3%E3%82%99%E3%83%B3%E3%82%BF%E3%81%8B%E3%81%AA-OFL-1.1.md).

## Legal Notice

This project is NOT affiliated with Bazzite, Dux Labs, Seafoam Labs, Umbriel or Tsuburaya.

The software is developed independently and provided as-is, without warranties of any kind. Use at your own risk.

