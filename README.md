<br><br><br>
<p align=center>
  <img src="assets/spacium.svg" alt="Spacium" width="478">
</p>
<br><br>

# Spacium

<p>
  <a href="https://github.com/irunatbullets/spacium/actions/workflows/update-image.yml"><img src="https://github.com/irunatbullets/spacium/actions/workflows/update-image.yml/badge.svg" alt="Update image"></a> <a href="https://github.com/irunatbullets/spacium"><img src="https://img.shields.io/github/last-commit/irunatbullets/spacium" alt="Last Commit"></a>
</p>

This custom **Bazzite** image is based on `bazzite-gnome` with variants for the Nvidia open driver as well as Nouveau.

It swaps the GNOME session for **Noctalia** (desktop shell) and **Umbriel**
(Wayland compositor), using the **Noctalia Greeter** for the login screen.

My goal with this image is to offer a vanilla Noctalia/Umbriel experience with
gaming capabilities (via Bazzite).

Feel free to suggest additional software - or just fork this repo and do
whatever you like.

To switch, run one of the following commands from a terminal in any Universal
Blue or Fedora Atomic based install.

Choose from the following based on your gpu needs (amd, nvidia, or legacy nvidia):

```
sudo bootc switch ghcr.io/irunatbullets/spacium
```

```
sudo bootc switch ghcr.io/irunatbullets/spacium-nvidia
```

```
sudo bootc switch ghcr.io/irunatbullets/spacium-nouveau
```

**Important Note:** After switching to this image the login will backup any
existing Umbriel configuration (`~/.config/umbriel`) and replace it with the
standard Spacium Umbriel config (which autostarts Noctalia). Updates will not
retrigger this event.

## What my selection of additional applications achieve

- **gnome-terminal** - the default terminal, opened with `Mod+Return` in Umbriel.
- **bluetui** - an application for configuring multiple Bluetooth receivers.

## Known issues and workarounds

### Where does Noctalia/Umbriel come from?

`noctalia` comes from the official Fedora 44 repositories. `umbriel-nightly`,
`noctalia-greeter` and `xdg-desktop-portal-umbriel-nightly` come from the
[**Terra**](https://terrapkg.com/) repository, the Fedora source documented
upstream (and already used by Bazzite for other packages). Bazzite ships Terra
but leaves it disabled, and Terra's main server (`repos.fyralabs.com`) is often
unreachable, so the build pulls those packages from Terra's CDN mirror
(`repos-cf.fyralabs.com`) without enabling the repo persistently.

### Why does the build replace Xwayland?

The packaged Umbriel depends on `xwayland-satellite`, which requires Fedora's
`xorg-x11-server-Xwayland`. Bazzite ships Terra's build of Xwayland, which
conflicts with Fedora's, so the build swaps Terra's Xwayland for Fedora's (the
same upstream version) using `dnf --allowerasing`. As a result
`xwayland-satellite` is installed even though upstream Umbriel now uses
wlroots' native Xwayland.

### Screen sharing

Screen capture and sharing go through **xdg-desktop-portal-umbriel**, which is
installed and configured automatically. If an application can't share the
screen, make sure it is using the portal.

### The Noctalia Greeter doesn't match my Noctalia wallpaper

The greeter can sync its appearance with your Noctalia session. See the
[greeter sync documentation](https://docs.noctalia.dev/greeter/sync/) for the
polkit-authorized setup steps.

## Credits:

- https://bazzite.gg/
- https://noctalia.dev/
- https://docs.noctalia.dev/
- https://github.com/noctalia-dev/noctalia
- https://github.com/noctalia-dev/umbriel
- https://github.com/noctalia-dev/noctalia-greeter
- https://tsuburaya-prod.com/ (for Ultraman, the inspiration behind the name of this image)
- https://zone108.main.jp/s/jp-005gontakana.php<br>FZゴンタかな is licensed under the [SIL Open Font License, Version 1.1](https://github.com/irunatbullets/spacium/blob/5ce3fb4974ead6809fc2b79f841c56f48572e577/assets/licenses/FZ%E3%82%B3%E3%82%99%E3%83%B3%E3%82%BF%E3%81%8B%E3%81%AA-OFL-1.1.md).

## Legal Notice

This project is NOT affiliated with Bazzite, Noctalia, Umbriel or Tsuburaya.

The software is developed independently and provided as-is, without warranties of any kind. Use at your own risk.

