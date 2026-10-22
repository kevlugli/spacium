ARG BASE_IMAGE=ghcr.io/ublue-os/bazzite-gnome:stable

# Aqueous revision to build (branch, tag or commit).
ARG AQUEOUS_REF=master

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS buildctx
COPY build_files /ctx/

# ---------------------------------------------------------------------------
# Build Aqueous from source.
#
# Aqueous has no Fedora package and its installer refuses to run on bootc
# hosts, so build it in a plain Fedora 44 stage and install the resulting RPM
# into the image. The full component set is staged (core, session, welcome,
# portal and the DMS/Noctalia/Pearl integrations). Fedora's hwdata has no
# pkg-config file, which wlroots' DRM backend needs, so one is provided.
# ---------------------------------------------------------------------------
FROM registry.fedoraproject.org/fedora:44 AS aqueous-builder

ARG AQUEOUS_REF

RUN dnf -y install dnf5-plugins sudo git && dnf clean all

RUN mkdir -p /usr/share/pkgconfig && \
    printf '%s\n' \
      'prefix=/usr' \
      'pkgdatadir=${prefix}/share/hwdata' \
      'Name: hwdata' \
      'Description: Hardware identification and configuration data' \
      'Version: 0' \
      > /usr/share/pkgconfig/hwdata.pc

RUN useradd -m builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder && \
    chmod 440 /etc/sudoers.d/builder

RUN dnf -y copr enable avengemedia/dms-git && \
    dnf -y copr enable avengemedia/danklinux && \
    dnf -y copr enable lionheartp/Hyprland && \
    dnf clean all

# Extra -devel packages the upstream Fedora recipe does not pull (Xwayland and
# several xcb modules are only found through pkg-config).
RUN dnf -y install \
        xorg-x11-server-Xwayland-devel \
        libasan \
        libubsan \
        libxcb-devel \
        xcb-util-wm-devel \
        xcb-util-errors-devel \
        xcb-util-renderutil-devel \
        xcb-util-devel \
        xcb-util-cursor-devel \
        pipewire-devel \
        libdisplay-info-devel \
        libliftoff-devel \
        mesa-libEGL-devel \
        mesa-libgbm-devel \
        wayland-devel \
        wayland-protocols-devel \
        libxkbcommon-devel \
        libinput-devel \
        libevdev-devel \
        pixman-devel \
        libdrm-devel \
        lcms2-devel \
        systemd-devel \
        libdecor-devel \
        vulkan-loader-devel \
        vulkan-headers && \
    dnf clean all

RUN su builder -c "git clone --depth=1 --branch '${AQUEOUS_REF}' https://github.com/Seafoam-Labs/Aqueous.git /home/builder/Aqueous"

RUN su builder -c 'cd /home/builder/Aqueous && bash scripts/fedora-install.sh --build-only -y' && \
    find /home/builder/.cache/aqueous/fedora -name '*.rpm' -exec cp -v {} /aqueous.rpm \;

FROM ${BASE_IMAGE} AS base

COPY --from=aqueous-builder /aqueous.rpm /aqueous.rpm

COPY system_files/etc/ /etc/
COPY system_files/usr/ /usr/

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
RUN --mount=type=bind,from=buildctx,source=/ctx,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
