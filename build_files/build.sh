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
# Umbriel comes from the c0mpile COPR. Terra's umbriel-nightly is frozen at
# 2026-10-03 and that build's IPC rejects the whole event subscription with
# "unknown subscription event: outputs" -- an event Noctalia 5.3.0 subscribes to.
# Without that event stream Noctalia shows no windows at all.
dnf5 -y copr enable c0mpile/builds

# The packaged Umbriel depends on xwayland-satellite, which in turn requires
# Fedora's xorg-x11-server-Xwayland. Bazzite ships Terra's build of Xwayland,
# which conflicts with Fedora's, so replace it with Fedora's (same upstream
# version) before pulling Umbriel in.
dnf5 -y install --allowerasing xorg-x11-server-Xwayland

dnf5 -y install \
    acl \
    bluetui \
    cava \
    cliphist \
    gnome-terminal \
    greetd \
    noctalia \
    tmux \
    umbriel-git \
    wl-clipboard

dnf5 -y copr disable irunatbullets/spacium-extras
dnf5 -y copr disable c0mpile/builds

# The Noctalia Greeter and the Umbriel portal come from Terra, the Fedora source
# documented upstream (and already used by Bazzite for other packages). Bazzite
# ships Terra but leaves it disabled, and Terra's main server
# (repos.fyralabs.com) is often unreachable, so use its CDN mirror directly.
dnf5 -y install \
    --repofrompath 'terra-cf,https://repos-cf.fyralabs.com/terra$releasever' \
    --nogpgcheck \
    noctalia-greeter \
    xdg-desktop-portal-umbriel-nightly

systemctl enable podman.socket

systemctl disable gdm
systemctl enable greetd

# ==============================================================================
# Noctalia Greeter (greetd)
# ==============================================================================

# Unprivileged account greetd uses to run the greeter session.
tee /usr/lib/sysusers.d/greeter.conf > /dev/null <<'EOF'
g greeter 767
u greeter 767 "Noctalia Greeter" /var/lib/noctalia-greeter /usr/sbin/nologin
m greeter video
m greeter input
EOF

systemd-sysusers /usr/lib/sysusers.d/greeter.conf || true

mkdir -p /var/lib/noctalia-greeter
chown -R 767:767 /var/lib/noctalia-greeter
chmod 0750 /var/lib/noctalia-greeter

# greetd needs a systemd PAM session for the greeter compositor.
if [ -f /etc/pam.d/greetd ] && ! grep -qF pam_systemd.so /etc/pam.d/greetd; then
  printf '\nsession    required     pam_systemd.so\n' >> /etc/pam.d/greetd
fi

# Create the greeter configuration files (greeter.toml / sync.toml).
GREETER_USER=greeter noctalia-greeter-apply-appearance --setup-system || true

# ==============================================================================
# Umbriel session defaults
# ==============================================================================

# Seed a starter Umbriel config for new users: autostart Noctalia and open
# gnome-terminal on Mod+Return. Umbriel reads ~/.config/umbriel/config.toml,
# falling back to the packaged /usr/share/umbriel/config.toml, so patch both.
sed -i \
    -e 's|^# \[general\]$|[general]|' \
    -e 's|^# autostart = .*$|autostart = ["noctalia"]|' \
    -e 's|^autostart = .*$|autostart = ["noctalia"]|' \
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
