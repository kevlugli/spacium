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
    cliphist \
    cava \
    dms \
    dux-calendar-git \
    dux-gop \
    dux-greeter \
    dux-search \
    greetd \
    ghostty \
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
MANDARA_VERSION="${MANDARA_VERSION:-0.7.0}"
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

# --- AppManager (official AnyLinux AppImage; no Fedora/COPR package) ---
# The bundle already carries GTK4/libadwaita, zsync2 (delta updates) and
# dwarfsextract (DwarFS images), so nothing else is needed at runtime.
APPMANAGER_VERSION="${APPMANAGER_VERSION:-3.8.0}"
case "$(uname -m)" in
  x86_64)
    APPMANAGER_ARCH="x86_64"
    APPMANAGER_SHA256="599685be011e11971a3115c38f40b00ad84b123b0dd925a655d109e0ad93fac2"
    ;;
  aarch64)
    APPMANAGER_ARCH="aarch64"
    APPMANAGER_SHA256="a2a990162b45fef8f28ef7f6975d796d87ea01990e9c618e9ac27048f421474f"
    ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
APPMANAGER_DIR="/usr/lib/app-manager"
APPMANAGER_APPIMAGE="${APPMANAGER_DIR}/app-manager.AppImage"
install -d -m 0755 "$APPMANAGER_DIR"
curl -fsSL -o "$APPMANAGER_APPIMAGE" \
    "https://github.com/kem-a/AppManager/releases/download/v${APPMANAGER_VERSION}/AppManager-${APPMANAGER_VERSION}-anylinux-${APPMANAGER_ARCH}.AppImage"
echo "${APPMANAGER_SHA256}  ${APPMANAGER_APPIMAGE}" | sha256sum -c -
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

