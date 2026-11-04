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

It ships **Umbriel** as the Wayland compositor and **Mandara** as the desktop
shell, with **Mandara Login** as the login screen on top of greetd.

My goal with this image is to offer a minimal Umbriel + Mandara experience with
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

**Important Note:** niri and Dank Material Shell are no longer installed. The
session is Umbriel; GNOME is still present from the Bazzite base and can be
picked at the login screen.

## What my selection of additional applications achieve

- **bluetui** - an application for configuring multiple Bluetooth receivers.
- **umbriel** - the Wayland compositor, built from source with local patches.
- **mandara** - the desktop shell (bar, launcher, lock screen, settings).
- **appmanager** - a GTK4 app for installing and updating AppImages.
- **wl-mirror** - mirrors a Wayland output, e.g. into a window or a stream.

## Known issues and workarounds

### How do I change the login screen?

The login screen is **Mandara Login**, started by greetd through `cage`:

```
mandara greeter --demo          # preview it without logging out
mandara studio "login screen"   # edit the design and apply it
```

Mandara Login is the only greeter installed. If it ever fails to start, switch
to a text console with `Ctrl+Alt+F2` and check `journalctl -u greetd`.

### How is Mandara started?

Automatically. On the first login, `spacium-setup.service` runs before the
compositor and creates `~/.config/umbriel/config.toml` with the include line
that loads Mandara's drop-in, then generates the drop-in itself
(`~/.config/mandara/generated/umbriel.toml`). Its `[general] autostart` entry
launches Mandara with the session.

If you already have an Umbriel config it is left untouched. To wire it up by
hand:

```
mandara setup --compositor umbriel --autostart
```

and add the `[include.optional]` snippet it prints to your
`~/.config/umbriel/config.toml`.

## Credits:

- https://bazzite.gg/
- https://github.com/noctalia-dev/umbriel
- https://github.com/theHamdiz/mandara
- https://tsuburaya-prod.com/ (for Ultraman, the inspiration behind the name of this image)
- https://zone108.main.jp/s/jp-005gontakana.php<br>FZゴンタかな is licensed under the [SIL Open Font License, Version 1.1](https://github.com/irunatbullets/spacium/blob/5ce3fb4974ead6809fc2b79f841c56f48572e577/assets/licenses/FZ%E3%82%B3%E3%82%99%E3%83%B3%E3%82%BF%E3%81%8B%E3%81%AA-OFL-1.1.md).

## Legal Notice

This project is NOT affiliated with Bazzite, Noctalia, Mandara or Tsuburaya.

The software is developed independently and provided as-is, without warranties of any kind. Use at your own risk.

