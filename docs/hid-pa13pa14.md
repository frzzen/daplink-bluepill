# Blue Pill DAPLink — HID-only + PA13/PA14 SWD

基于 `bluepill-hid-only` 的 USB（纯 HID CMSIS-DAP v1）+ `bluepill-vcom-pb6pb7` 的引脚（复用板载 SWD）。

| 功能 | 引脚 | 说明 |
|------|------|------|
| SWCLK | **PA14** | 板载 SWD CLK（作探针输出） |
| SWDIO | **PA13** | 板载 SWD DIO（双向） |
| nRESET | **PB8** | PB6 给 VCOM TX；可悬空 |
| VCOM TX | **PB6** | USART1 remap → 目标 RX |
| VCOM RX | **PB7** | USART1 remap ← 目标 TX |
| LED | PC13 | 低电平亮 |
| USB soft-connect | PA12 | 同前 |

## USB

- **Product string**：`BluePill CMSIS-DAP v1`（`USBD_STRDESC_PROD`）
- **HID interface string**：`BluePill CMSIS-DAP v1`（`USBD_HID_STRDESC`；pyOCD Probe 列用此名）
- 序列号仍为芯片 UID；Manufacturer 为 `Tekrit`
- **CMSIS-DAP**：仅 HID v1（EP1 IN/OUT；`projects.yaml` 的 `stm32f103xb_if` **不**包含 `usb-bulk.yaml`）
- **无 WinUSB / Bulk CMSIS-DAP v2**（F103 PMA 放不下 HID+Bulk）
- CDC / WebUSB：保留；**无 MSC**（no-target IF，不做目标盘拖放）

macOS / Linux 可直接用 pyOCD、OpenOCD 走 HID，无需 WinUSB。

## 接线（本板作为 DAPLink 时）

```
本板 PA14 → 目标 SWCLK
本板 PA13 → 目标 SWDIO
本板 PB8  → 目标 nRESET（可选）
本板 PB6  → 目标 UART RX
本板 PB7  ← 目标 UART TX
本板 GND  — 目标 GND
```

## 注意

固件启动后会 `__HAL_AFIO_REMAP_SWJ_DISABLE()`，板载 SWD（PA13/PA14）变为探针 GPIO。
再用 WCH-Link / 技新烧本板需 **connect under reset** 或 BOOT0 ISP。

## 产物

`bluepill/firmware-hid-pa13pa14/daplink_bluepill_full_128k_hid_pa13pa14.{bin,hex}`

重新编译：

```bash
export ARM_GCC_BIN=/path/to/gcc-arm-none-eabi-10.3-2021.10/bin   # 可选
OUT=bluepill/firmware-hid-pa13pa14 ./bluepill/rebuild.sh
# 再重命名 daplink_bluepill_full_128k.bin/hex 为 *_hid_pa13pa14.*
```

## 代码要点

- `projects.yaml` — 去掉 `usb-bulk.yaml`（HID-only）
- `IO_Config.h` / `DAP_config.h` / `gpio.c` — PA13/PA14 SWD，全关 SWJ
- `uart.c` — USART1 remap PB6/PB7；nRESET=PB8
