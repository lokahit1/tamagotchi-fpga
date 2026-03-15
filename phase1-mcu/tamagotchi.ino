// ============================================================
// TAMAGOTCHI — DIY Virtual Pet
// Arduino Nano + SSD1306 OLED + 3 Buttons + Piezo Buzzer
// ============================================================
// Wiring:
//   OLED SDA  → A4
//   OLED SCL  → A5
//   OLED VCC  → 5V
//   OLED GND  → GND
//   BTN_LEFT  → D2 (10kΩ pull-down to GND)
//   BTN_MID   → D3 (10kΩ pull-down to GND)
//   BTN_RIGHT → D4 (10kΩ pull-down to GND)
//   BUZZER +  → D9 (PWM)
//   BUZZER -  → GND
// ============================================================
// Libraries needed (install via Arduino Library Manager):
//   - Adafruit SSD1306
//   - Adafruit GFX Library
// ============================================================

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ----- Display Setup -----
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ----- Pin Definitions -----
#define BTN_LEFT   2
#define BTN_MID    3
#define BTN_RIGHT  4
#define BUZZER     9

// ----- Pet States -----
enum PetState {
  STATE_HAPPY,
  STATE_HUNGRY,
  STATE_SICK,
  STATE_SLEEPING,
  STATE_DEAD
};

// ----- Menu Items -----
enum MenuItem {
  MENU_FEED,
  MENU_PLAY,
  MENU_CLEAN,
  MENU_STATS,
  MENU_COUNT  // always last — gives us the count
};

const char* menuLabels[] = { "FEED", "PLAY", "CLEAN", "STATS" };

// ----- Pet Data -----
struct Pet {
  uint8_t hunger;     // 0 = full, 100 = starving
  uint8_t happiness;  // 0 = sad, 100 = max happy
  uint8_t health;     // 0 = dead, 100 = perfect
  uint8_t poop;       // 0 = clean, 5 = filthy
  uint8_t age;        // days alive
  PetState state;
  bool isSleeping;
};

Pet pet = { 20, 80, 100, 0, 0, STATE_HAPPY, false };

// ----- Timing -----
unsigned long lastTickMs      = 0;
unsigned long lastAnimMs      = 0;
unsigned long lastBtnMs       = 0;
const unsigned long TICK_INTERVAL  = 5000;   // pet stats update every 5s (speed up for testing; real = 60s)
const unsigned long ANIM_INTERVAL  = 500;    // sprite animation frame toggle
const unsigned long BTN_DEBOUNCE   = 200;    // button debounce

// ----- Animation -----
uint8_t animFrame     = 0;
uint8_t selectedMenu  = 0;
bool    showMenu      = false;
bool    showMessage   = false;
char    messageText[16];
unsigned long messageStartMs = 0;

// ============================================================
//  PIXEL ART SPRITES (16x16 bitmaps)
// ============================================================
// Each sprite is 16x16 pixels = 32 bytes
// Use Adafruit GFX drawBitmap() — 1 = white pixel, 0 = black

// Happy face — frame 1 (standing)
const uint8_t PROGMEM spriteHappy1[] = {
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001100, 0b00110010,
  0b10001100, 0b00110001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10010000, 0b00001001,
  0b10001000, 0b00010001,
  0b01000111, 0b11100010,
  0b01000000, 0b00000010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000,
  0b00000000, 0b00000000
};

// Happy face — frame 2 (bouncing up)
const uint8_t PROGMEM spriteHappy2[] = {
  0b00000000, 0b00000000,
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001100, 0b00110010,
  0b10001100, 0b00110001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10010000, 0b00001001,
  0b10001000, 0b00010001,
  0b01000111, 0b11100010,
  0b01000000, 0b00000010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000
};

// Hungry face (frowning)
const uint8_t PROGMEM spriteHungry[] = {
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001100, 0b00110010,
  0b10001100, 0b00110001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000111, 0b11100001,
  0b01001000, 0b00010010,
  0b01010000, 0b00001010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000,
  0b00000000, 0b00000000
};

// Sick face (X eyes)
const uint8_t PROGMEM spriteSick[] = {
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001010, 0b01010010,
  0b10000100, 0b00100001,
  0b10001010, 0b01010001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000011, 0b11000001,
  0b01000000, 0b00000010,
  0b01000000, 0b00000010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000,
  0b00000000, 0b00000000
};

// Sleeping face (ZZZ)
const uint8_t PROGMEM spriteSleep[] = {
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001110, 0b01110010,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000000, 0b00000001,
  0b10000011, 0b11000001,
  0b01000000, 0b00000010,
  0b01000000, 0b00000010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000,
  0b00000000, 0b00000000
};

// Dead face (X_X)
const uint8_t PROGMEM spriteDead[] = {
  0b00000111, 0b11100000,
  0b00011000, 0b00011000,
  0b00100000, 0b00000100,
  0b01000000, 0b00000010,
  0b01001010, 0b01010010,
  0b10000100, 0b00100001,
  0b10001010, 0b01010001,
  0b10000000, 0b00000001,
  0b10011111, 0b11111001,
  0b10000000, 0b00000001,
  0b01000000, 0b00000010,
  0b01000000, 0b00000010,
  0b00100000, 0b00000100,
  0b00011000, 0b00011000,
  0b00000111, 0b11100000,
  0b00000000, 0b00000000
};

// Poop sprite (8x8)
const uint8_t PROGMEM spritePoop[] = {
  0b00010000,
  0b00101000,
  0b00010000,
  0b01111100,
  0b11111110,
  0b11111110,
  0b01111100,
  0b00000000
};

// Heart sprite (8x8) — for feeding animation
const uint8_t PROGMEM spriteHeart[] = {
  0b01100110,
  0b11111111,
  0b11111111,
  0b11111111,
  0b01111110,
  0b00111100,
  0b00011000,
  0b00000000
};

// Music note sprite (8x8) — for play animation
const uint8_t PROGMEM spriteNote[] = {
  0b00001100,
  0b00001110,
  0b00001100,
  0b00001000,
  0b00001000,
  0b01111000,
  0b11111000,
  0b01110000
};

// ============================================================
//  SOUND EFFECTS
// ============================================================

void beepFeed() {
  tone(BUZZER, 880, 100);
  delay(120);
  tone(BUZZER, 1100, 100);
  delay(120);
  tone(BUZZER, 1320, 150);
  delay(160);
  noTone(BUZZER);
}

void beepPlay() {
  for (int i = 0; i < 3; i++) {
    tone(BUZZER, 660 + i * 220, 80);
    delay(100);
  }
  noTone(BUZZER);
}

void beepClean() {
  tone(BUZZER, 1000, 60);
  delay(80);
  tone(BUZZER, 1200, 60);
  delay(80);
  noTone(BUZZER);
}

void beepSad() {
  tone(BUZZER, 440, 200);
  delay(220);
  tone(BUZZER, 330, 300);
  delay(320);
  noTone(BUZZER);
}

void beepDeath() {
  for (int freq = 880; freq > 200; freq -= 40) {
    tone(BUZZER, freq, 50);
    delay(60);
  }
  noTone(BUZZER);
}

void beepSelect() {
  tone(BUZZER, 1000, 30);
  delay(40);
  noTone(BUZZER);
}

// ============================================================
//  PET LOGIC
// ============================================================

void updatePetState() {
  if (pet.state == STATE_DEAD) return;

  // Hunger increases over time
  if (pet.hunger < 100) pet.hunger += 2;

  // Happiness decreases over time
  if (pet.happiness > 0) pet.happiness -= 1;

  // Poop accumulates slowly
  if (random(0, 5) == 0 && pet.poop < 5) pet.poop += 1;

  // Health affected by hunger and poop
  if (pet.hunger > 80 && pet.health > 0) pet.health -= 3;
  if (pet.poop >= 3 && pet.health > 0)   pet.health -= 2;
  if (pet.hunger < 40 && pet.poop == 0 && pet.health < 100) pet.health += 1;

  // Determine visual state
  if (pet.health == 0) {
    pet.state = STATE_DEAD;
    beepDeath();
  } else if (pet.health < 30) {
    pet.state = STATE_SICK;
  } else if (pet.hunger > 70) {
    pet.state = STATE_HUNGRY;
  } else if (pet.isSleeping) {
    pet.state = STATE_SLEEPING;
  } else {
    pet.state = STATE_HAPPY;
  }
}

void feedPet() {
  if (pet.state == STATE_DEAD) return;
  if (pet.hunger > 15) {
    pet.hunger -= 15;
  } else {
    pet.hunger = 0;
  }
  if (pet.happiness < 95) pet.happiness += 5;
  beepFeed();
  showTemporaryMessage("YUM!");
}

void playWithPet() {
  if (pet.state == STATE_DEAD) return;
  if (pet.happiness < 85) {
    pet.happiness += 15;
  } else {
    pet.happiness = 100;
  }
  if (pet.hunger < 95) pet.hunger += 5;  // playing makes you hungry!
  beepPlay();
  showTemporaryMessage("FUN!");
}

void cleanPet() {
  if (pet.state == STATE_DEAD) return;
  if (pet.poop > 0) {
    pet.poop = 0;
    beepClean();
    showTemporaryMessage("CLEAN!");
  } else {
    showTemporaryMessage("ALREADY CLEAN");
  }
}

void showTemporaryMessage(const char* msg) {
  showMessage = true;
  strncpy(messageText, msg, 15);
  messageText[15] = '\0';
  messageStartMs = millis();
}

// ============================================================
//  DISPLAY RENDERING
// ============================================================

void drawPet() {
  // Pet sprite position (centered)
  int px = 56;  // (128 - 16) / 2
  int py = 16;

  const uint8_t* sprite;

  switch (pet.state) {
    case STATE_HAPPY:
      sprite = (animFrame == 0) ? spriteHappy1 : spriteHappy2;
      break;
    case STATE_HUNGRY:
      sprite = spriteHungry;
      break;
    case STATE_SICK:
      sprite = spriteSick;
      break;
    case STATE_SLEEPING:
      sprite = spriteSleep;
      break;
    case STATE_DEAD:
      sprite = spriteDead;
      break;
    default:
      sprite = spriteHappy1;
  }

  display.drawBitmap(px, py, sprite, 16, 16, WHITE);

  // Draw poop sprites to the right of pet
  for (uint8_t i = 0; i < pet.poop; i++) {
    display.drawBitmap(90 + (i * 10), 28, spritePoop, 8, 8, WHITE);
  }

  // Sleeping ZZZ animation
  if (pet.state == STATE_SLEEPING && animFrame == 1) {
    display.setTextSize(1);
    display.setCursor(78, 10);
    display.print("z");
    display.setCursor(84, 6);
    display.print("Z");
    display.setCursor(92, 2);
    display.print("Z");
  }
}

void drawStatusBars() {
  int barY = 40;
  int barWidth = 40;
  int barHeight = 5;

  // Hunger bar (inverted: full bar = not hungry)
  display.setTextSize(1);
  display.setCursor(0, barY);
  display.print("HNG");
  int hungerFill = map(100 - pet.hunger, 0, 100, 0, barWidth);
  display.drawRect(24, barY, barWidth, barHeight, WHITE);
  display.fillRect(24, barY, hungerFill, barHeight, WHITE);

  // Happiness bar
  display.setCursor(70, barY);
  display.print("HAP");
  int happyFill = map(pet.happiness, 0, 100, 0, barWidth);
  display.drawRect(94, barY, barWidth, barHeight, WHITE);
  display.fillRect(94, barY, happyFill, barHeight, WHITE);

  // Health bar
  barY = 49;
  display.setCursor(0, barY);
  display.print("HP");
  int healthFill = map(pet.health, 0, 100, 0, barWidth);
  display.drawRect(24, barY, barWidth, barHeight, WHITE);
  display.fillRect(24, barY, healthFill, barHeight, WHITE);

  // Poop indicator
  display.setCursor(70, barY);
  display.print("POO:");
  display.print(pet.poop);
}

void drawMenu() {
  int menuY = 57;
  int itemWidth = 32;

  for (uint8_t i = 0; i < MENU_COUNT; i++) {
    int x = i * itemWidth;
    if (i == selectedMenu) {
      display.fillRoundRect(x, menuY, itemWidth - 1, 7, 1, WHITE);
      display.setTextColor(BLACK);
    } else {
      display.setTextColor(WHITE);
    }
    display.setTextSize(1);
    display.setCursor(x + 2, menuY);
    display.print(menuLabels[i]);
    display.setTextColor(WHITE);
  }
}

void drawStatsScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);

  display.setCursor(30, 0);
  display.print("- PET STATS -");

  display.setCursor(0, 16);
  display.print("Hunger:    ");
  display.print(100 - pet.hunger);
  display.print("%");

  display.setCursor(0, 26);
  display.print("Happiness: ");
  display.print(pet.happiness);
  display.print("%");

  display.setCursor(0, 36);
  display.print("Health:    ");
  display.print(pet.health);
  display.print("%");

  display.setCursor(0, 46);
  display.print("Cleanliness: ");
  display.print(pet.poop == 0 ? "Spotless" : (pet.poop < 3 ? "OK" : "DIRTY!"));

  display.setCursor(0, 57);
  display.print("[MID] Back");

  display.display();
}

void drawMessageOverlay() {
  // Centered pop-up message
  int16_t x1, y1;
  uint16_t w, h;
  display.setTextSize(2);
  display.getTextBounds(messageText, 0, 0, &x1, &y1, &w, &h);
  int mx = (SCREEN_WIDTH - w) / 2;
  int my = 8;
  display.fillRoundRect(mx - 4, my - 2, w + 8, h + 4, 3, BLACK);
  display.drawRoundRect(mx - 4, my - 2, w + 8, h + 4, 3, WHITE);
  display.setCursor(mx, my);
  display.setTextSize(2);
  display.print(messageText);
  display.setTextSize(1);
}

void drawDeathScreen() {
  display.clearDisplay();

  // Draw dead sprite centered
  display.drawBitmap(56, 8, spriteDead, 16, 16, WHITE);

  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(28, 32);
  display.print("YOUR PET DIED");

  display.setCursor(20, 46);
  display.print("[MID] Try Again");

  display.display();
}

void render() {
  if (pet.state == STATE_DEAD) {
    drawDeathScreen();
    return;
  }

  display.clearDisplay();
  display.setTextColor(WHITE);

  drawPet();
  drawStatusBars();
  drawMenu();

  // Overlay message if active
  if (showMessage) {
    drawMessageOverlay();
    if (millis() - messageStartMs > 1000) {
      showMessage = false;
    }
  }

  display.display();
}

// ============================================================
//  BUTTON HANDLING
// ============================================================

bool showingStats = false;

void handleButtons() {
  if (millis() - lastBtnMs < BTN_DEBOUNCE) return;

  bool left  = digitalRead(BTN_LEFT);
  bool mid   = digitalRead(BTN_MID);
  bool right = digitalRead(BTN_RIGHT);

  if (!left && !mid && !right) return;
  lastBtnMs = millis();

  // Dead state — middle button restarts
  if (pet.state == STATE_DEAD) {
    if (mid) {
      pet = { 20, 80, 100, 0, 0, STATE_HAPPY, false };
      showingStats = false;
    }
    return;
  }

  // Stats screen — middle exits
  if (showingStats) {
    if (mid) {
      showingStats = false;
      beepSelect();
    }
    return;
  }

  // Normal mode
  if (left) {
    // Navigate menu left
    if (selectedMenu > 0) selectedMenu--;
    else selectedMenu = MENU_COUNT - 1;
    beepSelect();
  }

  if (right) {
    // Navigate menu right
    if (selectedMenu < MENU_COUNT - 1) selectedMenu++;
    else selectedMenu = 0;
    beepSelect();
  }

  if (mid) {
    // Execute selected menu action
    switch (selectedMenu) {
      case MENU_FEED:  feedPet();  break;
      case MENU_PLAY:  playWithPet(); break;
      case MENU_CLEAN: cleanPet(); break;
      case MENU_STATS:
        showingStats = true;
        beepSelect();
        break;
    }
  }
}

// ============================================================
//  SETUP & MAIN LOOP
// ============================================================

void setup() {
  Serial.begin(9600);

  // Initialize pins
  pinMode(BTN_LEFT,  INPUT);
  pinMode(BTN_MID,   INPUT);
  pinMode(BTN_RIGHT, INPUT);
  pinMode(BUZZER,    OUTPUT);

  // Initialize OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 failed!"));
    for (;;);  // halt
  }

  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(WHITE);
  display.setCursor(10, 10);
  display.print("TAMAGOTCHI");
  display.setTextSize(1);
  display.setCursor(30, 35);
  display.print("DIY Edition");
  display.setCursor(20, 50);
  display.print("Press any button");
  display.display();

  // Wait for button press to start
  while (!digitalRead(BTN_LEFT) && !digitalRead(BTN_MID) && !digitalRead(BTN_RIGHT)) {
    delay(50);
  }

  // Startup jingle
  tone(BUZZER, 660, 100); delay(120);
  tone(BUZZER, 880, 100); delay(120);
  tone(BUZZER, 1100, 150); delay(170);
  noTone(BUZZER);

  randomSeed(analogRead(A0));  // seed RNG from floating pin

  lastTickMs = millis();
  lastAnimMs = millis();
}

void loop() {
  unsigned long now = millis();

  // Handle button input
  handleButtons();

  // Update pet stats periodically
  if (now - lastTickMs >= TICK_INTERVAL) {
    lastTickMs = now;
    updatePetState();
  }

  // Toggle animation frame
  if (now - lastAnimMs >= ANIM_INTERVAL) {
    lastAnimMs = now;
    animFrame = 1 - animFrame;
  }

  // Render
  if (showingStats) {
    drawStatsScreen();
  } else {
    render();
  }

  delay(16);  // ~60fps cap
}
