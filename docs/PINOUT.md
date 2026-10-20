# Blue Pill DAPLink 管脚 / Pinout

本固件基于官方 ARMmbed DAPLink `stm32f103xb` HIC，管脚对齐
[RadioOperator](https://github.com/RadioOperator/STM32F103C8T6_CMSIS-DAP_SWO) **BLUEPILL SWD unRemap（PB8/PB9）**，
保留 **PA13/PA14** 给 WCH-Link / ST-Link 烧录本探针本身。

This firmware is official ARMmbed DAPLink with HIC pins remapped to the
RadioOperator Blue Pill **SWD unRemap** map. Probe SWDIO/SWCLK stay free for flashing.

## 目标调试口 Target SWD（接到被调试板）

| 功能 Function | 蓝丸 GPIO | 官方原脚 Official | 说明 Notes |
|---|---|---|---|
| SWCLK | **PB8** | PB13 | 时钟 Clock |
| SWDIO | **PB9** | PB14 出 + PB12 入 | 双向单脚 same pin IN+OUT |
| nRESET | **PB6** | PB0 | 开漏+上拉 OD + pull-up（可不接） |
| GND | GND | GND | 共地 |
| 3V3（可选） | 3.3V | — | 仅短线短时供电 |

> 不要用 SWD-Remap（PA13/PA14）版本：烧录探针自己时会冲突。
> Do not use the SWD-Remap (PA13/PA14) map — it blocks flashing the probe.

## USB / 串口 / LED

| 功能 Function | 蓝丸 GPIO | 说明 Notes |
|---|---|---|
| USB D− / D+ | PA11 / PA12 | 与官方相同 Same as official |
| USB soft-connect | **PA12 拉低模拟**（非 PA15） | 蓝丸 DP 硬 1k5：固件用 PA12 输出低模拟断开，就绪后改浮空输入让硬上拉开路重枚举；**不驱动 PA15** |
| CDC UART TX | **PA2** (USART2) | 接目标板 UART RX |
| CDC UART RX | **PA3** (USART2) | 接目标板 UART TX |
| CDC RTS / CTS | PA1 / PA0 | 可选，一般可悬空 |
| 状态 LED | **PC13** | 板载 LED，低电平点亮 active-low |
| 晶振 | 8 MHz HSE | 必须 Must |

## 保留给烧录探针的脚（勿接到目标）

| 功能 | GPIO |
|---|---|
| 探针自身 SWDIO | PA13 |
| 探针自身 SWCLK | PA14 |
| NRST（芯片复位） | NRST 排针 |

## 接线示意（调试其他板）

```
Blue Pill (DAPLink)          Target MCU
  PB9  SWDIO  ------------  SWDIO
  PB8  SWCLK  ------------  SWCLK
  PB6  nRESET ------------  NRST   (可选)
  PA2  TX     ------------  target RX  (VCOM)
  PA3  RX     ------------  target TX  (VCOM)
  GND         ------------  GND
  3V3         ------------  3V3    (可选，慎用)
```

## Flash 容量风险 Flash size

| MCU | Flash | 能否装完整 BL+IF |
|---|---|---|
| STM32F103**CBT6** | 128 KB（规格） | **可以（推荐）** |
| STM32F103**C8T6** | 规格 64 KB | **不行**（IF 从 48KB 偏移起） |
| C8T6 + 社区“后 64KB” | 非规格 | 多数真片可写满 128KB，**不保证**；复刻片常只有 64KB |

官方布局：BL `0x08000000` 大小 `0xBC00`，IF `0x0800C000` 大小 `0x13C00`，合计需约 **128 KB**。

## 与技新 CMSIS-DAP 对照（勿混用）

| 功能 | 本固件（蓝丸） | 技新 BOARD_V1 |
|---|---|---|
| SWDIO | PB9 | PA2 |
| SWCLK | PB8 | PA4 |
| nRESET | PB6 | PA6 |
| VCOM | USART2 PA2/PA3 | USART1 PA9/PA10 |
| LED | PC13 | PB8/PB12 |

