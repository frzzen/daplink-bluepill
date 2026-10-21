#!/usr/bin/env bash
# Copied from scripts/build.sh and changed to build a standalone Interface image (no bootloader).
# Does not modify build.sh. Remaps for 64 KiB Flash: IF at 0x08000000 (0xFC00) + config at 0x0800FC00; no BL.
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

# Standalone IF for 64 KiB Flash (STM32F103C8): IF + 1 KiB config, no BL.
python3 - <<'PY'
from pathlib import Path
p = Path("source/hic_hal/stm32/stm32f103xb/daplink_addr.h")
t = p.read_text()
repls = [
    ("#define DAPLINK_ROM_SIZE                0x00020000",
     "#define DAPLINK_ROM_SIZE                0x00010000"),
    ("#define DAPLINK_ROM_BL_SIZE             0x0000BC00",
     "#define DAPLINK_ROM_BL_SIZE             0x00000000"),
    ("#define DAPLINK_ROM_IF_START            0x0800C000",
     "#define DAPLINK_ROM_IF_START            0x08000000"),
    ("#define DAPLINK_ROM_IF_SIZE             0x00013C00",
     "#define DAPLINK_ROM_IF_SIZE             0x0000FC00"),
    ("#define DAPLINK_ROM_CONFIG_USER_START   0x0801FC00",
     "#define DAPLINK_ROM_CONFIG_USER_START   0x0800FC00"),
]
for a, b in repls:
    if a not in t:
        raise SystemExit(f"daplink_addr.h: expected line missing:\n{a}")
    t = t.replace(a, b, 1)
p.write_text(t)
print("daplink_addr.h: 64K Flash, IF @ 0x08000000 size 0xFC00, config @ 0x0800FC00")
PY

if [ ! -d venv ]; then python3 -m venv venv; . venv/bin/activate; pip install -r requirements.txt; else . venv/bin/activate; fi
# progen still imports pkg_resources; setuptools>=81 removed it
pip install -q 'setuptools<81'
python tools/pre_build_script.py --version_git_dir source/daplink/
progen generate -t make_gcc_arm -p stm32f103xb_if
sed -i 's/-Wl,-fatal-warnings//g' \
  projectfiles/make_gcc_arm/stm32f103xb_if/Makefile || true
# Makefile only depends on daplink.ld, not daplink_addr.h — force regen after remap.
make -C projectfiles/make_gcc_arm/stm32f103xb_if clean || true
rm -f projectfiles/make_gcc_arm/stm32f103xb_if/build/stm32f103xb_if.generated.ld
make -C projectfiles/make_gcc_arm/stm32f103xb_if -j"$(nproc)" all

mkdir -p "$OUT"
IF_SRC="projectfiles/make_gcc_arm/stm32f103xb_if/build/stm32f103xb_if_crc.bin"
IF_ELF="projectfiles/make_gcc_arm/stm32f103xb_if/build/stm32f103xb_if.elf"
cp "$IF_SRC" "$OUT/daplink_bluepill_if_only_64k.bin"
arm-none-eabi-objcopy -I binary -O ihex --change-addresses=0x08000000 \
  "$OUT/daplink_bluepill_if_only_64k.bin" "$OUT/daplink_bluepill_if_only_64k.hex"
OUT="$OUT" IF_ELF="$IF_ELF" python3 - <<'PY'
import os, subprocess
from pathlib import Path
out = Path(os.environ["OUT"])
data = (out / "daplink_bluepill_if_only_64k.bin").read_bytes()
body = data[:-4]
i = len(body)
while i > 0 and body[i - 1] == 0xFF:
    i -= 1
print(f"IF-only CRC image: {len(data)} B (link fill to 0xFC00 / 64K Flash)")
print(f"IF-only payload (excl. pad+CRC): {i} B")
print(f"Flash @ 0x08000000: {out / 'daplink_bluepill_if_only_64k.bin'}")
print(subprocess.check_output(["arm-none-eabi-size", os.environ["IF_ELF"]], text=True).rstrip())
PY
(cd "$OUT" && sha256sum daplink_bluepill_if_only_64k.bin daplink_bluepill_if_only_64k.hex > SHA256SUMS.if_only)
echo "Artifacts in $OUT (scripts/build.sh untouched)"
