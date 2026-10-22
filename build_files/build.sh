#!/bin/bash
set -ouex pipefail

IMAGE_NAME="${IMAGE_NAME:-spacium}"
IMAGE_VARIANT="${IMAGE_VARIANT:-}"

if [ -z "$IMAGE_VARIANT" ]; then
  FULL_NAME="$IMAGE_NAME"
else
  FULL_NAME="${IMAGE_NAME}-${IMAGE_VARIANT}"
fi

IMAGE_REF="ostree-image-signed:docker://ghcr.io/irunatbullets/${FULL_NAME}"

# bluetui comes from the project's own COPR.
dnf5 -y copr enable irunatbullets/spacium-extras
# Umbriel and its portal (Terra's umbriel-nightly is frozen at 2026-10-03 and
# its IPC rejects the "outputs" subscription event).
dnf5 -y copr enable c0mpile/builds
# DMS 2.0 (Dux Shell) and its greeter. The new Dux Labs repos are not complete
# for Fedora 44 yet, so use the AvengeMedia channels: dms-git carries 2.0 and
# danklinux carries quickshell, dgop, matugen and dms-greeter-git.
dnf5 -y copr enable avengemedia/dms-git
dnf5 -y copr enable avengemedia/danklinux
# uwsm (required by the Aqueous session) is not packaged in Fedora 44.
dnf5 -y copr enable lionheartp/Hyprland

# Umbriel depends on xwayland-satellite, which in turn requires Fedora's
# xorg-x11-server-Xwayland. Bazzite ships Terra's build of Xwayland, which
# conflicts with Fedora's, so replace it with Fedora's (same upstream version)
# before pulling Umbriel in.
dnf5 -y install --allowerasing xorg-x11-server-Xwayland

dnf5 -y install \
    acl \
    bluetui \
    cava \
    cliphist \
    dgop \
    dms \
    dms-greeter-git \
    gnome-terminal \
    greetd \
    matugen \
    quickshell \
    tmux \
    umbriel-git \
    uwsm \
    wl-clipboard \
    xdg-desktop-portal-umbriel-git

# Aqueous, built from source in the Containerfile builder stage.
dnf5 -y install /aqueous.rpm
rm -f /aqueous.rpm

dnf5 -y copr disable irunatbullets/spacium-extras
dnf5 -y copr disable c0mpile/builds
dnf5 -y copr disable avengemedia/dms-git
dnf5 -y copr disable avengemedia/danklinux
dnf5 -y copr disable lionheartp/Hyprland

systemctl enable podman.socket

systemctl disable gdm
systemctl enable greetd

# ==============================================================================
# DMS Greeter (greetd)
# ==============================================================================

# Unprivileged account greetd uses to run the greeter session.
tee /usr/lib/sysusers.d/greeter.conf > /dev/null <<'EOF'
g greeter 767
u greeter 767 "DMS greeter" /var/cache/dms-greeter /usr/sbin/nologin
m greeter video
m greeter input
EOF

systemd-sysusers /usr/lib/sysusers.d/greeter.conf || true

mkdir -p /var/cache/dms-greeter
chown -R 767:767 /var/cache/dms-greeter
chmod 0755 /var/cache/dms-greeter

# greetd needs a systemd PAM session for the greeter compositor.
if [ -f /etc/pam.d/greetd ] && ! grep -qF pam_systemd.so /etc/pam.d/greetd; then
  printf '\nsession    required     pam_systemd.so\n' >> /etc/pam.d/greetd
fi

# ==============================================================================
# Umbriel session defaults
# ==============================================================================

# Seed a starter Umbriel config for new users: autostart DMS and open
# gnome-terminal on Mod+Return. Umbriel reads ~/.config/umbriel/config.toml,
# falling back to the packaged /usr/share/umbriel/config.toml, so patch both.
sed -i \
    -e 's|^# \[general\]$|[general]|' \
    -e 's|^# autostart = .*$|autostart = ["dms run"]|' \
    -e 's|^autostart = .*$|autostart = ["dms run"]|' \
    -e 's|"spawn:kitty"|"spawn:gnome-terminal"|' \
    /usr/share/umbriel/config.toml

install -d /etc/skel/.config/umbriel
cp /usr/share/umbriel/config.toml /etc/skel/.config/umbriel/config.toml

# Apply the image defaults on first login, backing up any existing config.
mkdir -p /usr/lib/systemd/user/graphical-session.target.wants

ln -sf /usr/lib/systemd/user/spacium.service \
    /usr/lib/systemd/user/graphical-session.target.wants/spacium.service

jq \
  --arg name "$FULL_NAME" \
  --arg ref "$IMAGE_REF" \
  --arg tag "${IMAGE_VARIANT:-latest}" \
  '
  .["image-name"]=$name |
  .["image-ref"]=$ref |
  .["image-tag"]=$tag
  ' \
  /usr/share/ublue-os/image-info.json \
  > /tmp/image-info.json && mv /tmp/image-info.json /usr/share/ublue-os/image-info.json
