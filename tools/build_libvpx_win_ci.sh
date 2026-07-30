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

# gen_msvs_sln.sh writes the MSBuild recipe to vpx.sln.mk. The generated
# solution otherwise uses unrestricted project parallelism (`-m`), which lets
# vpx and vpxrc assemble a shared NASM object concurrently on hosted runners.
# Restrict this dependency to one MSBuild node to prevent truncated objects and
# LNK1136; the rest of the AyuGram build remains parallel.
SOLUTION_MAKEFILE="vpx.sln.mk"
ORIGINAL='$(MSBUILD_TOOL) vpx.sln -m -t:Build'
SERIALIZED='$(MSBUILD_TOOL) vpx.sln -m:1 -t:Build'

if [[ ! -f "$SOLUTION_MAKEFILE" ]]; then
  echo "[ERROR] Generated libvpx make fragment was not found: $SOLUTION_MAKEFILE" >&2
  exit 1
fi
if ! grep -Fq "$ORIGINAL" "$SOLUTION_MAKEFILE"; then
  echo '[ERROR] Expected libvpx MSBuild recipe was not found in vpx.sln.mk.' >&2
  grep -nF 'MSBUILD_TOOL' "$SOLUTION_MAKEFILE" >&2 || true
  exit 1
fi

sed -i 's/$(MSBUILD_TOOL) vpx\.sln -m -t:Build/$(MSBUILD_TOOL) vpx.sln -m:1 -t:Build/g' "$SOLUTION_MAKEFILE"

if grep -Fq "$ORIGINAL" "$SOLUTION_MAKEFILE"; then
  echo '[ERROR] Failed to disable libvpx MSBuild project parallelism.' >&2
  exit 1
fi
if ! grep -Fq "$SERIALIZED" "$SOLUTION_MAKEFILE"; then
  echo '[ERROR] Serialized libvpx MSBuild recipe was not produced.' >&2
  exit 1
fi

grep -nF "$SERIALIZED" "$SOLUTION_MAKEFILE"

make -j1
make -j1 install
