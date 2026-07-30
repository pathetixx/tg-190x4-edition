#!/usr/bin/env bash
set -e

FullExecPath=$PWD
pushd "$(dirname "$0")" > /dev/null
FullScriptPath=$(pwd)
popd > /dev/null

./configure --prefix="$FullScriptPath/../local" \
--target="$TOOLCHAIN" \
--disable-examples \
--disable-unit-tests \
--disable-tools \
--disable-docs \
--enable-static-msvcrt \
--enable-vp8 \
--enable-vp9 \
--enable-webm-io \
--size-limit=4096x4096

# libvpx generates a Visual Studio solution whose Makefile invokes MSBuild with
# unrestricted project parallelism (`-m`). On GitHub-hosted Windows runners the
# vpx and vpxrc projects can assemble the same NASM object concurrently, leaving
# a truncated .obj and failing with LNK1136. Force one MSBuild node for this
# dependency only; the rest of the AyuGram build remains parallel.
if ! grep -Fq 'msbuild.exe vpx.sln -m ' Makefile; then
  echo '[ERROR] Expected libvpx MSBuild command was not found in Makefile.' >&2
  exit 1
fi
sed -i 's/msbuild\.exe vpx\.sln -m /msbuild.exe vpx.sln -m:1 /g' Makefile
if grep -Fq 'msbuild.exe vpx.sln -m ' Makefile; then
  echo '[ERROR] Failed to disable libvpx MSBuild project parallelism.' >&2
  exit 1
fi
grep -F 'msbuild.exe vpx.sln -m:1 ' Makefile

make -j1
make -j1 install
