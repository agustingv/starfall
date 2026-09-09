#!/bin/sh
# Build raylib's static library with its own Makefile, then hand the archive to
# Meson. raylib ships no Meson build, but its Makefile is well maintained and
# handles all the desktop/GLFW/X11 wiring for us.
#
#   $1  path to raylib's src/ directory
#   $2  path Meson expects the finished libraylib.a at (@OUTPUT@)
set -eu

src_dir=$1
out=$2

jobs=$(nproc 2>/dev/null || echo 2)

make -C "$src_dir" \
    PLATFORM=PLATFORM_DESKTOP \
    RAYLIB_LIBTYPE=STATIC \
    RAYLIB_RELEASE_PATH="$src_dir" \
    -j "$jobs" \
    raylib

cp "$src_dir/libraylib.a" "$out"
