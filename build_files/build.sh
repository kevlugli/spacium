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

dnf5 -y copr enable irunatbullets/spacium-extras
dnf5 -y copr enable duxlabs/dms
dnf5 -y copr enable duxlabs/dux-repo

dnf5 -y install --enablerepo=terra \
    acl \
    bluetui \
    breakpad \
    cage \
    cliphist \
    cava \
    dms \
    dux-calendar-git \
    dux-gop \
    dux-greeter \
    dux-search \
    greetd \
    ghostty \
    gnome-keyring-pam \
    jemalloc \
    lcms2 \
    libdisplay-info \
    libeis \
    material-symbols-fonts \
    matugen \
    niri \
    qt6-qt5compat \
    qt6-qtimageformats \
    qt6-qtmultimedia \
    qt6-qtsvg \
    quickshell-git \
    tmux \
    tomlplusplus \
    wl-clipboard \
    wlroots \
    xcb-util-wm \
    xwayland-satellite

dnf5 -y copr disable irunatbullets/spacium-extras
dnf5 -y copr disable duxlabs/dms
dnf5 -y copr disable duxlabs/dux-repo

# --- Mandara Shell (official release RPM; no COPR or Fedora package) ---
# An empty MANDARA_VERSION means "latest published release". It is resolved
# from the releases/latest redirect, which avoids the unauthenticated GitHub
# API rate limit and keeps the image from going stale.
MANDARA_VERSION="${MANDARA_VERSION:-}"
if [ -z "$MANDARA_VERSION" ]; then
  MANDARA_TAG="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
    https://github.com/theHamdiz/mandara/releases/latest | sed 's#.*/tag/##')"
  MANDARA_VERSION="${MANDARA_TAG#v}"
fi
test -n "$MANDARA_VERSION"
echo "Installing mandara ${MANDARA_VERSION}"
case "$(uname -m)" in
  x86_64) MANDARA_ARCH="x86_64" ;;
  aarch64) MANDARA_ARCH="aarch64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
MANDARA_BASE="https://github.com/theHamdiz/mandara/releases/download/v${MANDARA_VERSION}"
MANDARA_RPM="mandara-${MANDARA_VERSION}-1.${MANDARA_ARCH}.rpm"
curl -fsSL -o /tmp/mandara-SHA256SUMS "${MANDARA_BASE}/SHA256SUMS"
curl -fsSL -o "/tmp/${MANDARA_RPM}" "${MANDARA_BASE}/${MANDARA_RPM}"
(cd /tmp && grep " ${MANDARA_RPM}$" mandara-SHA256SUMS | sha256sum -c -)
dnf5 -y install --nogpgcheck "/tmp/${MANDARA_RPM}"
rm -f /tmp/mandara-SHA256SUMS "/tmp/${MANDARA_RPM}"

# --- Mandara Login (greetd greeter, started through cage by /etc/greetd/config.toml) ---
# Symlink instead of copying the 173 MB binary; the greeter user still runs it
# under its expected name. The state directory comes from tmpfiles.d.
install -d /usr/lib/mandara \
    /usr/share/mandara/login/videos \
    /usr/share/mandara/login/backgrounds
ln -sfn /usr/bin/mandara /usr/lib/mandara/mandara-greeter

# Unlock GNOME Keyring with the password typed at the login screen, through
# greetd's PAM service. Idempotent: it only writes when the lines are missing.
mandara greeter keyring-unlock --apply

# --- AppManager (official AnyLinux AppImage; no Fedora/COPR package) ---
# The bundle already carries GTK4/libadwaita, zsync2 (delta updates) and
# dwarfsextract (DwarFS images), so nothing else is needed at runtime.
# An empty APPMANAGER_VERSION means "latest published release". It is resolved
# from the releases/latest redirect, which avoids the unauthenticated GitHub
# API rate limit.
APPMANAGER_VERSION="${APPMANAGER_VERSION:-}"
if [ -z "$APPMANAGER_VERSION" ]; then
  APPMANAGER_TAG="$(curl -fsS -o /dev/null -w '%{redirect_url}' \
    https://github.com/kem-a/AppManager/releases/latest | sed 's#.*/tag/##')"
  APPMANAGER_VERSION="${APPMANAGER_TAG#v}"
fi
test -n "$APPMANAGER_VERSION"
echo "Installing AppManager ${APPMANAGER_VERSION}"
case "$(uname -m)" in
  x86_64) APPMANAGER_ARCH="x86_64" ;;
  aarch64) APPMANAGER_ARCH="aarch64" ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
APPMANAGER_ASSET="AppManager-${APPMANAGER_VERSION}-anylinux-${APPMANAGER_ARCH}.AppImage"
APPMANAGER_URL="https://github.com/kem-a/AppManager/releases/download/v${APPMANAGER_VERSION}/${APPMANAGER_ASSET}"
APPMANAGER_DIR="/usr/lib/app-manager"
APPMANAGER_APPIMAGE="${APPMANAGER_DIR}/app-manager.AppImage"
install -d -m 0755 "$APPMANAGER_DIR"
curl -fsSL -o "$APPMANAGER_APPIMAGE" "$APPMANAGER_URL"

# Upstream publishes no checksums or signature, only the zsync manifest, which
# carries the SHA-1 of the whole file. It is the only integrity reference
# available now that the version follows the latest release.
curl -fsSL -o /tmp/appmanager.zsync "${APPMANAGER_URL}.zsync"
APPMANAGER_SHA1="$(sed -n 's/^SHA-1: *//p' /tmp/appmanager.zsync | head -1)"
test -n "$APPMANAGER_SHA1"
echo "${APPMANAGER_SHA1}  ${APPMANAGER_APPIMAGE}" | sha1sum -c -
rm -f /tmp/appmanager.zsync
chmod 0755 "$APPMANAGER_APPIMAGE"

# Keep the bundle out of /usr/bin; expose it through a small launcher instead.
cat > /usr/bin/app-manager <<'EOF'
#!/bin/sh
exec /usr/lib/app-manager/app-manager.AppImage "$@"
EOF
chmod 0755 /usr/bin/app-manager

# Desktop entry and icon come from the bundle itself (Exec=/usr/bin/app-manager).
(cd /tmp && "$APPMANAGER_APPIMAGE" --appimage-extract >/dev/null)
install -Dm644 /tmp/squashfs-root/com.github.AppManager.desktop \
    /usr/share/applications/com.github.AppManager.desktop
install -Dm644 /tmp/squashfs-root/com.github.AppManager.svg \
    /usr/share/icons/hicolor/scalable/apps/com.github.AppManager.svg
rm -rf /tmp/squashfs-root

gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
update-desktop-database -q /usr/share/applications || true

# --- VS Code repository: Microsoft GPG key (the .repo comes from system_files) ---
mkdir -p /etc/pki/rpm-gpg
curl -fsSL -o /etc/pki/rpm-gpg/RPM-GPG-KEY-microsoft https://packages.microsoft.com/keys/microsoft.asc
chmod 0644 /etc/pki/rpm-gpg/RPM-GPG-KEY-microsoft
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-microsoft

systemctl enable podman.socket

systemctl --global enable dms

systemctl disable gdm
systemctl enable greetd

mkdir -p /var/cache/dms-greeter

tee /usr/lib/sysusers.d/greeter.conf > /dev/null <<'EOF'
g greeter 767
u greeter 767 "greetd greeter" /var/lib/greeter
EOF

mkdir -p /var/lib/greeter
chown 767:767 /var/lib/greeter

mkdir -p /usr/lib/systemd/user/graphical-session.target.wants

ln -s /usr/lib/systemd/user/spacium.service \
    /usr/lib/systemd/user/graphical-session.target.wants/spacium.service

ln -s /usr/lib/systemd/user/dsearch.service \
    /usr/lib/systemd/user/graphical-session.target.wants/dsearch.service

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

# Fail the build if the umbriel copied from the build stage has unresolved libraries.
if ldd /usr/bin/umbriel | grep 'not found'; then
  echo "umbriel has unresolved shared library dependencies" >&2
  exit 1
fi

