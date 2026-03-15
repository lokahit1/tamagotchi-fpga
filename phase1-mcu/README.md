# TAMAGOTCHI — DIY Virtual Pet

A fully functional Tamagotchi clone built with Arduino Nano.

## Hardware Required

| Part                          | Pin        | Notes                     |
|-------------------------------|------------|---------------------------|
| Arduino Nano                  | —          | Brain (ATmega328P)        |
| SSD1306 OLED 0.96" (I2C)     | A4, A5     | 128×64 pixels             |
| Tactile Button × 3           | D2, D3, D4 | Left, Middle, Right       |
| 10kΩ Resistor × 3            | —          | Pull-down for each button |
| Passive Piezo Buzzer          | D9         | PWM for tones             |
| Breadboard + Jumper Wires     | —          | For prototyping           |

## Wiring Diagram

```
OLED Display:
  VCC → 5V
  GND → GND
  SDA → A4
  SCL → A5

Buttons (each one):
  5V ─── [BUTTON] ──┬── D2 / D3 / D4
                     │
                   [10kΩ]
                     │
                    GND

Buzzer:
  (+) → D9
  (-) → GND
```

## Software Setup

1. Install Arduino IDE (https://www.arduino.cc/en/software)
2. Open Library Manager (Sketch → Include Library → Manage Libraries)
3. Install these libraries:
   - **Adafruit SSD1306** (by Adafruit)
   - **Adafruit GFX Library** (by Adafruit)
4. Open `tamagotchi.ino`
5. Select Board: **Arduino Nano**
6. Select Processor: **ATmega328P** (or "Old Bootloader" for clones)
7. Select your COM port
8. Upload!

## How to Play

### Controls
- **LEFT button (D2)**: Navigate menu left
- **MIDDLE button (D3)**: Select / Confirm
- **RIGHT button (D4)**: Navigate menu right

### Menu Options
| Option | Action                                    |
|--------|-------------------------------------------|
| FEED   | Reduces hunger, slight happiness boost    |
| PLAY   | Big happiness boost, slight hunger cost   |
| CLEAN  | Removes poop (cleanliness affects health) |
| STATS  | Shows detailed stats screen               |

### Pet States
- **Happy**: Bouncing animation — pet is doing well!
- **Hungry**: Frowning face — hunger is above 70%
- **Sick**: X-eyes — health has dropped below 30%
- **Sleeping**: Closed eyes + ZZZ — pet is resting
- **Dead**: Game over — press MIDDLE to restart

### Tips
- Feed regularly before hunger bar empties
- Clean poop quickly — it damages health over time
- Playing keeps happiness up but makes the pet hungrier
- Health regenerates when hunger is low AND poop is cleaned

## Customization Ideas

- **Speed**: Change `TICK_INTERVAL` (default 5000ms for testing, set to 60000 for real-time)
- **Difficulty**: Adjust hunger/happiness change rates in `updatePetState()`
- **Sprites**: Edit the bitmap arrays to create your own pixel art creature
- **Sounds**: Modify the `beep*()` functions with different frequencies
- **Mini-games**: Add a simple reaction game in `playWithPet()`

## Creating Custom Sprites

Each 16×16 sprite is stored as 32 bytes (2 bytes per row).
Use an online tool like:
- https://www.pixilart.com (draw 16x16)
- https://javl.github.io/image2cpp/ (convert PNG to byte array)

Export as "Arduino code" format, paste into the sprite arrays.

## Phase 2: FPGA Port

Once the MCU version works, the game logic (state machine, timers, display
driver) can be ported to Verilog for an FPGA like the Tang Nano 9K.
This makes an excellent VLSI portfolio project demonstrating:
- FSM design (pet states)
- SPI/I2C peripheral interfacing (OLED driver)
- Timer/counter design (real-time pet aging)
- Memory management (sprite ROM)
