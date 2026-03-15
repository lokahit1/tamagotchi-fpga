# Tamagotchi FPGA — DIY Virtual Pet in Hardware

A Tamagotchi-style virtual pet built from scratch in two phases:
- **Phase 1**: Arduino Nano prototype (C firmware)
- **Phase 2**: Pure Verilog implementation on iCE40UP5K FPGA (no CPU — 100% hardware)

> This is a VLSI/digital design portfolio project demonstrating FSM design, SPI peripheral interfacing, hardware timer/counters, sprite ROM, and FPGA synthesis using a fully open-source toolchain.

## Project Status

| Module | Phase 1 (Arduino) | Phase 2 (FPGA) |
|--------|:-:|:-:|
| Game state machine | Done | Done |
| SPI display driver | Library | Done |
| Button debouncing | Software delay | Done (shift register) |
| Buzzer/PWM tones | Done | Done |
| Sprite storage | PROGMEM arrays | Done (LUT ROM) |
| Display controller | Library | In progress |
| Clock generation | Hardware crystal | Done (SB_HFOSC) |
| Top-level integration | Single file | Done |

## Hardware

### Phase 1 — MCU Prototype
- Arduino Nano (ATmega328P)
- SSD1306 0.96" OLED (I2C, 128×64)
- 3× tactile buttons + 10kΩ pull-down resistors
- Passive piezo buzzer

### Phase 2 — FPGA Implementation
- Muse Lab iCESugar (Lattice iCE40UP5K — 5,280 LUTs)
- SSD1306 0.96" OLED (SPI mode, 128×64)
- 3× tactile buttons + 10kΩ pull-down resistors
- Passive piezo buzzer

## Repository Structure

```
tamagotchi-fpga/
├── README.md
├── phase1-mcu/
│   ├── tamagotchi.ino        # Arduino firmware (complete)
│   └── README.md             # Wiring guide + setup
├── phase2-fpga/
│   ├── Makefile              # Open-source build system
│   ├── icesugar.pcf          # Pin constraints (iCESugar)
│   ├── rtl/
│   │   ├── tamagotchi_top.v  # Top-level module
│   │   ├── clock_divider.v   # Internal oscillator → 12MHz/1Hz/4Hz
│   │   ├── btn_debounce.v    # Shift register debouncer
│   │   ├── game_fsm.v        # Pet state machine
│   │   ├── sprite_rom.v      # Pixel art bitmap ROM
│   │   ├── spi_master.v      # SPI Mode 0 shift register
│   │   └── buzzer_pwm.v      # Programmable tone generator
│   └── tb/
│       └── (testbenches — coming soon)
└── docs/
    └── (schematics, pin maps — coming soon)
```

## Build & Run

### Phase 1 (Arduino)
1. Install [Arduino IDE](https://www.arduino.cc/en/software)
2. Install libraries: Adafruit SSD1306, Adafruit GFX
3. Open `phase1-mcu/tamagotchi.ino`
4. Upload to Arduino Nano

### Phase 2 (FPGA)
```bash
# Install open-source toolchain
# Download OSS CAD Suite from:
# https://github.com/YosysHQ/oss-cad-suite-build/releases

# Build
cd phase2-fpga
make

# Program (drag-and-drop)
# Copy build/tamagotchi.bin onto iCELink USB drive

# Or program via command line
make flash

# Simulate
make sim
```

## Toolchain

| Tool | Role |
|------|------|
| Yosys | RTL synthesis (Verilog → netlist) |
| nextpnr-ice40 | Place & route (netlist → physical layout) |
| IceStorm / icepack | Bitstream generation |
| Icarus Verilog | Simulation |
| GTKWave | Waveform viewer |

## FPGA Resource Usage (estimated)

| Module | LUTs | Description |
|--------|------|-------------|
| clock_divider | ~50 | Internal oscillator + dividers |
| btn_debounce ×3 | ~120 | Shift register + edge detect |
| game_fsm | ~300 | States, counters, menu logic |
| sprite_rom | ~200 | 9 sprites in LUT ROM |
| spi_master | ~80 | 8-bit SPI shift register |
| display_controller | ~200 | Framebuffer + SPI sequencer |
| buzzer_pwm | ~30 | Frequency divider |
| **Total** | **~980** | **19% of 5,280 available** |

## Skills Demonstrated

- **FSM design** — multi-state game logic with transitions and counters
- **SPI protocol** — hardware implementation of SPI Mode 0 from scratch
- **Memory design** — sprite ROM using synthesized LUT-based storage
- **Clock domain management** — internal oscillator with multiple derived clocks
- **Input conditioning** — hardware debouncing with shift registers and edge detection
- **PWM generation** — programmable frequency tone output
- **Full FPGA flow** — synthesis → place & route → bitstream → programming

## License

MIT
