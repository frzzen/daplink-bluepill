# BluePill CMSIS-DAP（蓝丸 DAPLink）

蓝丸（STM32F103）CMSIS-DAP 探针固件。**DAPLink 源码以 Git submodule 引入**，本仓库只保留蓝丸补丁、构建脚本与发布固件。

上游：[ARMmbed/DAPLink](https://github.com/ARMmbed/DAPLink)（钉在 `UPSTREAM_SHA.txt`）  
当前发布：**[v1.1.0](https://github.com/frzzen/daplink-bluepill/releases/tag/v1.1.0)**

## 功能

| 项 | 说明 |
|---|---|
| USB | Manufacturer `Tekrit`，Product / HID `BluePill CMSIS-DAP v1`（协议代次，非发行号） |
| CMSIS-DAP | 仅 HID v1（无 WinUSB / Bulk） |
| SWD | PA14 SWCLK / PA13 SWDIO（关 SWJ） |
| nRESET | PB8 |
| VCOM | PB6 TX / PB7 RX |

pyOCD 列表：`Tekrit BluePill CMSIS-DAP v1`

## 目录

```
DAPLink/                 # submodule → ARMmbed/DAPLink
patches/                 # 蓝丸差异补丁
scripts/build.sh         # 打补丁并编译 128K 镜像
firmware/                # 预编译 bin/hex（与 Release 一致）
docs/                    # 引脚与变体说明
```

## 获取与编译

```bash
git clone --recurse-submodules https://github.com/frzzen/daplink-bluepill.git
cd daplink-bluepill
# 需要 GNU Arm Embedded（建议 10.3）
export ARM_GCC_BIN=/path/to/gcc-arm-none-eabi-10.3-2021.10/bin
./scripts/build.sh
```

产物：`firmware/daplink_bluepill_full_128k_hid_pa13pa14.{bin,hex}`

## 烧录

128 KB Flash，地址 `0x08000000`（pyOCD 目标可用 `stm32f103rc`）：

```text
python -m pyocd erase -t stm32f103rc -f 4000k -M soft --chip
python -m pyocd flash -t stm32f103rc -f 4000k -M soft firmware/daplink_bluepill_full_128k_hid_pa13pa14.bin
```

更多接线见 [docs/hid-pa13pa14.md](docs/hid-pa13pa14.md)。

## 许可

- 上游 DAPLink：**Apache 2.0**（见 submodule 内 `LICENSE`）
- 本仓库补丁与脚本同样按 Apache 2.0 分发；改动见 `patches/`
