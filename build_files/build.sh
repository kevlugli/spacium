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
# Noctalia, Umbriel, the Noctalia Greeter and the Umbriel portal are packaged
# for Fedora 44 in this community COPR. Fedora itself only ships `noctalia`.
dnf5 -y copr enable c0mpile/builds

dnf5 -y install \
    acl \
    bluetui \
    cava \
    cliphist \
    ghostty \
    greetd \
    noctalia \
    noctalia-greeter-git \
    tmux \
    umbriel-git \
    wl-clipboard \
    xdg-desktop-portal-umbriel-git \
    xorg-x11-server-Xwayland

dnf5 -y copr disable irunatbullets/spacium-extras
dnf5 -y copr disable c0mpile/builds

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

# Seed a starter Umbriel config for new users: autostart Noctalia and use
# ghostty as the default terminal. Umbriel reads ~/.config/umbriel/config.toml,
# falling back to the packaged /usr/share/umbriel/config.toml, so patch both.
sed -i \
    -e 's|^# \[general\]$|[general]|' \
    -e 's|^# autostart = .*$|autostart = ["noctalia"]|' \
    -e 's|^autostart = .*$|autostart = ["noctalia"]|' \
    -e 's|"spawn:kitty"|"spawn:ghostty"|' \
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
