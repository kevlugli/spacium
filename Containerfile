ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome:stable

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS buildctx
COPY build_files /ctx/

# umbriel (Wayland compositor) built from source with local patches.
# The commit is pinned because the patches were generated against it.
FROM ${BASE_IMAGE} AS umbriel-build

ARG UMBRIEL_COMMIT=a37ae93f8e190a352ae9804e366a82e33a0199d1

COPY patches /tmp/patches

RUN --mount=type=cache,dst=/var/cache \
    set -eux; \
    # Bazzite excludes Fedora's mesa (it ships its own build) and hides
    # terra-mesa, which breaks installing mesa-libgbm-devel. This stage is
    # throwaway, so drop the overrides to get a plain build toolchain.
    rm -rf /etc/dnf/repos.override.d /etc/dnf/versionlock.toml; \
    dnf5 -y install \
        gcc-c++ git meson ninja-build pkgconf-pkg-config \
        wlroots-devel wayland-devel wayland-protocols-devel \
        libxkbcommon-devel libinput-devel libeis-devel \
        pixman-devel libdrm-devel libdisplay-info-devel \
        cairo-devel pango-devel tomlplusplus-devel json-devel \
        libxcb-devel xcb-util-wm-devel systemd-devel \
        libglvnd-devel mesa-libgbm-devel lcms2-devel jemalloc-devel; \
    git init /tmp/umbriel; \
    git -C /tmp/umbriel remote add origin https://github.com/noctalia-dev/umbriel.git; \
    git -C /tmp/umbriel fetch --depth 1 origin "${UMBRIEL_COMMIT}"; \
    git -C /tmp/umbriel checkout --detach FETCH_HEAD; \
    for p in /tmp/patches/*.patch; do git -C /tmp/umbriel apply "$p"; done; \
    meson setup /tmp/umbriel/build /tmp/umbriel \
        --buildtype=release --strip -Dtests=disabled --prefix=/usr; \
    meson compile -C /tmp/umbriel/build; \
    DESTDIR=/out meson install -C /tmp/umbriel/build --no-rebuild; \
    test -x /out/usr/bin/umbriel

# AppManager ships an official distro-agnostic AppImage (AnyLinux) that already
# bundles GTK4/libadwaita, zsync2 for delta updates and dwarfsextract for DwarFS
# images. It is installed by build.sh into /usr/bin.

FROM ${BASE_IMAGE} AS base

ARG MANDARA_VERSION=
ARG APPMANAGER_VERSION=

COPY --from=umbriel-build /out/ /

COPY system_files/etc/ /etc/
COPY system_files/usr/ /usr/

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
RUN --mount=type=bind,from=buildctx,source=/ctx,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    env MANDARA_VERSION="${MANDARA_VERSION}" APPMANAGER_VERSION="${APPMANAGER_VERSION}" /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint

