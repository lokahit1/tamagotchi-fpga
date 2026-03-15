# Tamagotchi FPGA — iCESugar (iCE40UP5K)

A virtual pet implemented entirely in hardware using Verilog on the
Lattice iCE40UP5K FPGA. No CPU, no software — pure digital logic.

## Project structure

```
tamagotchi-ice40/
├── Makefile              # Build system (make → program)
├── icesugar.pcf          # Pin constraints (which wire → which pin)
├── rtl/
│   ├── tamagotchi_top.v  # Top-level: wires everything together
│   ├── clock_divider.v   # Internal 48MHz osc → 12MHz/1Hz/4Hz
│   ├── btn_debounce.v    # Cleans noisy button signals
│   ├── game_fsm.v        # Pet state machine (the brain)
│   ├── sprite_rom.v      # Pixel art bitmap storage
│   ├── spi_master.v      # SPI protocol for OLED
│   ├── buzzer_pwm.v      # Tone generator for buzzer
│   └── display_controller.v  # TODO: framebuffer + SPI sequencer
└── tb/
    └── tamagotchi_tb.v   # TODO: simulation testbench
```

## Hardware required

- iCESugar FPGA board (iCE40UP5K)
- SSD1306 0.96" OLED (SPI mode, 128x64)
- 3x tactile buttons + 3x 10kΩ resistors
- Passive piezo buzzer
- Jumper wires

## Build & program

```bash
# Install toolchain (macOS)
brew install yosys nextpnr icestorm

# Build bitstream
make

# Program (drag-and-drop)
# Copy build/tamagotchi.bin onto the iCELink USB drive in Finder

# Or program via command line
make flash
```

## Module descriptions

| Module             | LUTs (est.) | What it does                              |
|--------------------|-------------|-------------------------------------------|
| clock_divider      | ~50         | Generates 12MHz, 1Hz, 4Hz from internal osc |
| btn_debounce (×3)  | ~40 each    | Shift-register debouncing + edge detect   |
| game_fsm           | ~300        | Pet states, counters, menu, sound triggers |
| sprite_rom         | ~200        | 9 sprites stored as LUT-based ROM         |
| spi_master         | ~80         | 8-bit SPI Mode 0 shift register           |
| display_controller | ~200        | Reads sprites, builds screen, feeds SPI   |
| buzzer_pwm         | ~30         | Programmable frequency square wave        |
| **Total**          | **~1000**   | **Out of 5,280 available (19% used)**     |

## Wiring

### PMOD 1 → OLED (SPI mode)
| PMOD pin | iCE40 pin | Signal    |
|----------|-----------|-----------|
| 1        | 4         | SCLK      |
| 2        | 2         | MOSI      |
| 3        | 47        | CS        |
| 4        | 45        | DC        |
| 5        | 3         | RES       |
| 3V3      | —         | VCC       |
| GND      | —         | GND       |

### PMOD 3 → Buttons + Buzzer
| PMOD pin | iCE40 pin | Signal    |
|----------|-----------|-----------|
| 1        | 27        | BTN Left  |
| 2        | 25        | BTN Mid   |
| 3        | 21        | BTN Right |
| 4        | 19        | Buzzer    |
| GND      | —         | Common GND |

## Remaining work

The `display_controller.v` module is the final piece — it needs to:
1. Send the SSD1306 initialization command sequence over SPI
2. Read game state and sprite ROM to build pixel data
3. Stream the framebuffer to the OLED page by page

This is the most complex module. A good approach is to implement
it as a multi-stage FSM: INIT → RENDER → SEND → WAIT → RENDER...
