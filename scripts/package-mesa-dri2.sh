#!/usr/bin/env bash
# Package PearMac's verified Mesa 25 R300 legacy-DRI2 GLX fix without
# overwriting Debian-owned Mesa files.
set -euo pipefail

src="${1:?Usage: package-mesa-dri2.sh /path/to/staged/pearmac-mesa-dri2 /output/dir}"
out="${2:?Missing output directory}"
version="25.0.7-2+deb13u1"
pkg="pearmac-mesa-r300-dri2"
debver="${version}.pearmac1"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

mkdir -p "$root/DEBIAN" "$root/opt/pearmac-radeon/lib" \
  "$root/opt/pearmac-radeon/private" "$root/etc/ld.so.conf.d" \
  "$root/usr/share/doc/$pkg" "$out"

libs="$src/lib/x86_64-linux-gnu"
test -f "$libs/libGLX_mesa.so.0.0.0"
test -f "$libs/libgallium-25.0.7.so"

# Expose ONLY the GLX vendor library to the system dynamic linker.
# Keep its matching Gallium build private to prevent unrelated EGL/GBM
# and video drivers from loading a reduced Gallium build.
install -m 0644 "$libs/libGLX_mesa.so.0.0.0" "$root/opt/pearmac-radeon/lib/"
ln -s libGLX_mesa.so.0.0.0 "$root/opt/pearmac-radeon/lib/libGLX_mesa.so.0"
install -m 0644 "$libs/libgallium-25.0.7.so" "$root/opt/pearmac-radeon/private/"

patchelf --set-rpath '$ORIGIN/../private' \
  "$root/opt/pearmac-radeon/lib/libGLX_mesa.so.0.0.0"

# The earlier-sorted conf fragment should give PearMac's libGLX_mesa.so.0
# precedence without overwriting any Debian-controlled library.
printf '%s\n' '/opt/pearmac-radeon/lib' > "$root/etc/ld.so.conf.d/00-pearmac-radeon.conf"

cat > "$root/DEBIAN/control" <<EOF
Package: $pkg
Version: $debver
Architecture: amd64
Maintainer: PearMac project <noreply@github.com>
Section: libs
Priority: optional
Depends: libglx-mesa0 (= $version), mesa-libgallium (= $version), libgl1-mesa-dri, libc6 (>= 2.41)
Description: Legacy DRI2 GLX compatibility for the Radeon X1600 on Q4OS 6
 Opt-in system GLX override for the early Intel iMac5,1 / R300.
 The vendor GLX library is built from Debian Mesa 25.0.7 with
 legacy-x11=dri2; its private Gallium library is isolated under /opt.
 The regular Debian Mesa files remain installed and unmodified.
EOF

cat > "$root/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = configure ]; then
    ldconfig
fi
exit 0
EOF
cat > "$root/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
case "$1" in
    remove|purge|upgrade|disappear)
        ldconfig
        ;;
esac
exit 0
EOF
chmod 0755 "$root/DEBIAN/postinst" "$root/DEBIAN/postrm"

cat > "$root/usr/share/doc/$pkg/README" <<'EOF'
PearMac Radeon X1600 legacy DRI2 Mesa GLX compatibility
=======================================================

TARGET: Q4OS 6 / Debian 13 amd64, Mesa 25.0.7-2+deb13u1, Xorg DRI2 and
Radeon X1600 (RV530 / R300 Gallium), booted through legacy BIOS mode.

INSTALL (from a terminal; do not install through a GUI during testing):
  sudo apt install ./pearmac-mesa-r300-dri2_*.deb
  ldconfig -p | grep libGLX_mesa.so.0
  glxinfo -B

Expected: ATI RV530 / Accelerated: yes. If needed for debugging:
  LIBGL_DRI3_DISABLE=1 glxinfo -B

WARNING: Global GLX override affects ALL GLX applications, including the
desktop. It does not provide OpenGL 3+, GLES 3+, Vulkan or Chromium GPU
compatibility. Do NOT remove or replace the original Debian Mesa packages.

SAFE ROLLBACK (from a working terminal):
  sudo apt remove pearmac-mesa-r300-dri2
  sudo ldconfig

EMERGENCY ROLLBACK (if GUI does not work):
  Enter a text TTY (Ctrl+Alt+F2), log in, and run the above two commands.
  If no TTY is accessible, boot Q4OS live DVD and temporarily disable the
  override by moving this file out of /etc/ld.so.conf.d/ of installed root:
    00-pearmac-radeon.conf
  Then chroot into the installed OS if necessary and run ldconfig.
  Do not blindly modify disk partitions.

Compatibility dependency pins deliberately reject a mismatch with the
original Debian Mesa version. On Mesa package upgrades, rebuild this fix.
EOF
chmod 0644 "$root/usr/share/doc/$pkg/README"

dpkg-deb --build --root-owner-group "$root" "$out/${pkg}_${debver}_amd64.deb"
dpkg-deb --info "$out/${pkg}_${debver}_amd64.deb"
dpkg-deb --contents "$out/${pkg}_${debver}_amd64.deb"

# Prove that our GLX bundle has the expected private-gallium runtime path.
readelf -d "$root/opt/pearmac-radeon/lib/libGLX_mesa.so.0.0.0" \
  | grep -F '$ORIGIN/../private'

printf 'Built %s\n' "$out/${pkg}_${debver}_amd64.deb"
