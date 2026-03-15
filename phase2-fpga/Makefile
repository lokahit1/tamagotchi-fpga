# ============================================================
# Makefile — Tamagotchi FPGA Build (iCE40UP5K / iCESugar)
# ============================================================
# Open-source toolchain:
#   Yosys        — synthesis (Verilog → netlist)
#   nextpnr-ice40 — place & route (netlist → physical layout)
#   icepack      — bitstream generation (layout → .bin)
#   iceprog      — programming (optional, or drag-and-drop)
#
# Install on macOS:
#   brew install yosys nextpnr icestorm
#
# Or download OSS CAD Suite:
#   https://github.com/YosysHQ/oss-cad-suite-build/releases
# ============================================================

# Project name
PROJ = tamagotchi

# FPGA device
DEVICE = up5k
PACKAGE = sg48

# Source files
VERILOG_SRC = \
	rtl/tamagotchi_top.v \
	rtl/clock_divider.v \
	rtl/btn_debounce.v \
	rtl/game_fsm.v \
	rtl/sprite_rom.v \
	rtl/spi_master.v \
	rtl/buzzer_pwm.v \
	rtl/display_controller.v

# Constraints
PCF = icesugar.pcf

# Output files
JSON = build/$(PROJ).json
ASC  = build/$(PROJ).asc
BIN  = build/$(PROJ).bin

# ---- Default target ----
all: $(BIN)

# ---- Create build directory ----
build:
	mkdir -p build

# ---- Step 1: Synthesis (Verilog → JSON netlist) ----
# Yosys reads your Verilog, understands the logic, and
# converts it to a netlist of iCE40 primitives (LUTs, FFs, etc.)
$(JSON): $(VERILOG_SRC) | build
	yosys -p "read_verilog $(VERILOG_SRC); synth_ice40 -top tamagotchi_top -json $@"

# ---- Step 2: Place & Route (netlist → physical layout) ----
# nextpnr maps each LUT/FF to a physical cell on the chip
# and routes the wires between them
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 \
		--$(DEVICE) \
		--package $(PACKAGE) \
		--pcf $(PCF) \
		--json $(JSON) \
		--asc $@ \
		--freq 12

# ---- Step 3: Bitstream Pack (layout → binary) ----
# icepack converts the ASCII layout to binary bitstream
# that the FPGA can understand
$(BIN): $(ASC)
	icepack $(ASC) $@

# ---- Program via drag-and-drop ----
# On macOS, the iCESugar shows up as a USB drive.
# Copy the .bin file to it:
program: $(BIN)
	@echo ""
	@echo "============================================"
	@echo "  Bitstream ready: $(BIN)"
	@echo ""
	@echo "  To program iCESugar:"
	@echo "    Option 1: Drag $(BIN) onto the iCELink"
	@echo "              USB drive in Finder"
	@echo ""
	@echo "    Option 2: Run this command:"
	@echo "              iceprog $(BIN)"
	@echo "============================================"
	@echo ""

# ---- Program via iceprog (command line) ----
flash: $(BIN)
	iceprog $(BIN)

# ---- Timing analysis ----
timing: $(ASC)
	icetime -d $(DEVICE) $(ASC)

# ---- Resource usage report ----
stats: $(JSON)
	yosys -p "read_verilog $(VERILOG_SRC); synth_ice40 -top tamagotchi_top; stat"

# ---- Simulation (using Icarus Verilog) ----
sim:
	mkdir -p build
	iverilog -o build/$(PROJ)_tb.vvp \
		$(VERILOG_SRC) \
		tb/tamagotchi_tb.v
	vvp build/$(PROJ)_tb.vvp
	@echo "Open build/$(PROJ)_tb.vcd in GTKWave to view waveforms"

# ---- Clean ----
clean:
	rm -rf build

.PHONY: all program flash timing stats sim clean
