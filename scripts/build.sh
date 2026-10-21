#!/usr/bin/env bash
# Apply Blue Pill patches onto DAPLink submodule and build 128K HID PA13/PA14 image.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DL="$ROOT/DAPLink"
OUT="${OUT:-$ROOT/firmware}"
PATCH="$ROOT/patches/0001-bluepill-hid-pa13pa14-tekrit.patch"
UPSTREAM="$(tr -d ' \n' < "$ROOT/UPSTREAM_SHA.txt")"

[ -e "$DL/.git" ] || { echo "Missing DAPLink submodule. Run: git submodule update --init --recursive"; exit 1; }
command -v arm-none-eabi-gcc >/dev/null || { echo "arm-none-eabi-gcc not found"; exit 1; }
[ -n "${ARM_GCC_BIN:-}" ] && export PATH="$ARM_GCC_BIN:$PATH"

cd "$DL"
git fetch --depth 1 origin "$UPSTREAM" 2>/dev/null || git fetch origin "$UPSTREAM" || true
git checkout --force "$UPSTREAM"
git clean -fdx -e venv -e projectfiles 2>/dev/null || git clean -fd
git apply --check "$PATCH"
git apply "$PATCH"

if [ ! -d venv ]; then python3 -m venv venv; . venv/bin/activate; pip install -r requirements.txt; else . venv/bin/activate; fi
# progen still imports pkg_resources; setuptools>=81 removed it
pip install -q 'setuptools<81'
python tools/pre_build_script.py --version_git_dir source/daplink/
progen generate -t make_gcc_arm -p stm32f103xb_bl
progen generate -t make_gcc_arm -p stm32f103xb_if
sed -i 's/-Wl,-fatal-warnings//g' \
  projectfiles/make_gcc_arm/stm32f103xb_bl/Makefile \
  projectfiles/make_gcc_arm/stm32f103xb_if/Makefile || true
# projectfiles/ is kept across clean; force fresh link scripts after addr layout changes.
make -C projectfiles/make_gcc_arm/stm32f103xb_bl clean || true
make -C projectfiles/make_gcc_arm/stm32f103xb_if clean || true
rm -f projectfiles/make_gcc_arm/stm32f103xb_bl/build/*.generated.ld \
      projectfiles/make_gcc_arm/stm32f103xb_if/build/*.generated.ld
make -C projectfiles/make_gcc_arm/stm32f103xb_bl -j"$(nproc)" all
make -C projectfiles/make_gcc_arm/stm32f103xb_if -j"$(nproc)" all

mkdir -p "$OUT"
cp projectfiles/make_gcc_arm/stm32f103xb_bl/build/stm32f103xb_bl_crc.bin "$OUT/bl.bin"
cp projectfiles/make_gcc_arm/stm32f103xb_if/build/stm32f103xb_if_crc.bin "$OUT/if.bin"
# IF CRC image for BL MSC drag-drop upgrade (link @ 0x0800C000). Same bytes as IF in full_128k.
cp "$OUT/if.bin" "$OUT/daplink_bluepill_if_update_for_bl.bin"
arm-none-eabi-objcopy -I binary -O ihex --change-addresses=0x0800C000 \
  "$OUT/daplink_bluepill_if_update_for_bl.bin" "$OUT/daplink_bluepill_if_update_for_bl.hex"
OUT="$OUT" python3 - <<'PY'
import os
from pathlib import Path
out = Path(os.environ['OUT'])
bl = (out/'bl.bin').read_bytes()
iff = (out/'if.bin').read_bytes()
img = bytearray(b'\xFF'*0x20000)
img[0:len(bl)] = bl
img[0xC000:0xC000+len(iff)] = iff
(out/'daplink_bluepill_full_128k_hid_pa13pa14.bin').write_bytes(img)
print('OK', len(bl), len(iff), '->', out/'daplink_bluepill_full_128k_hid_pa13pa14.bin')
print('IF update for BL drag-drop:', out/'daplink_bluepill_if_update_for_bl.bin', len(iff), 'B')
PY
arm-none-eabi-objcopy -I binary -O ihex --change-addresses=0x08000000 \
  "$OUT/daplink_bluepill_full_128k_hid_pa13pa14.bin" "$OUT/daplink_bluepill_full_128k_hid_pa13pa14.hex"
(cd "$OUT" && sha256sum \
  daplink_bluepill_full_128k_hid_pa13pa14.bin daplink_bluepill_full_128k_hid_pa13pa14.hex \
  daplink_bluepill_if_update_for_bl.bin daplink_bluepill_if_update_for_bl.hex \
  > SHA256SUMS)
echo "Artifacts in $OUT"
