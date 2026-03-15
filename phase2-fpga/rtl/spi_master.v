// ============================================================
// spi_master.v — SPI Master for SSD1306 OLED
// ============================================================
// Shifts out one byte at a time on the MOSI line.
// Active-low chip select (CS). DC pin distinguishes
// command bytes (DC=0) from data bytes (DC=1).
//
// Interface:
//   clk       — system clock
//   rst_n     — active-low reset
//   data_in   — byte to send
//   dc_in     — 0 = command, 1 = data (latched on start)
//   start     — pulse high for one cycle to begin transfer
//   busy      — high while transfer is in progress
//   done      — pulses high for one cycle when transfer completes
//
// SPI outputs:
//   sclk_out  — SPI clock (directly drives OLED SCLK pin)
//   mosi_out  — SPI data  (directly drives OLED MOSI/SDA pin)
//   cs_out    — Chip select, active low
//   dc_out    — Data/Command pin for SSD1306
//
// SPI Mode 0: CPOL=0, CPHA=0
//   Data sampled on rising edge of SCLK
//   Data shifted on falling edge of SCLK
//   MSB first
// ============================================================

module spi_master (
    input  wire       clk,
    input  wire       rst_n,

    // Control interface
    input  wire [7:0] data_in,
    input  wire       dc_in,
    input  wire       start,
    output reg        busy,
    output reg        done,

    // SPI physical pins
    output reg        sclk_out,
    output reg        mosi_out,
    output reg        cs_out,
    output reg        dc_out
);

    // ---- Clock divider ----
    // The system clock is ~12 MHz (from iCE40 HFOSC/4).
    // We divide by 4 to get ~3 MHz SPI clock, which is
    // well within SSD1306's max of 10 MHz.
    parameter CLK_DIV = 4;           // must be even
    localparam HALF_DIV = CLK_DIV / 2;

    reg [$clog2(CLK_DIV)-1:0] clk_cnt;
    wire clk_tick = (clk_cnt == CLK_DIV - 1);
    wire half_tick = (clk_cnt == HALF_DIV - 1);

    // ---- Shift register ----
    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;    // counts 0..7 for 8 bits

    // ---- State machine ----
    localparam S_IDLE    = 2'd0;
    localparam S_SETUP   = 2'd1;  // set MOSI, CS low
    localparam S_SHIFT   = 2'd2;  // shifting bits out
    localparam S_FINISH  = 2'd3;  // release CS

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= S_IDLE;
            shift_reg <= 8'd0;
            bit_cnt   <= 4'd0;
            clk_cnt   <= 0;
            sclk_out  <= 1'b0;
            mosi_out  <= 1'b0;
            cs_out    <= 1'b1;  // CS inactive (high)
            dc_out    <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;  // default: done is a single-cycle pulse

            case (state)
                // ---- IDLE: wait for start pulse ----
                S_IDLE: begin
                    sclk_out <= 1'b0;
                    cs_out   <= 1'b1;
                    busy     <= 1'b0;
                    if (start) begin
                        shift_reg <= data_in;
                        dc_out    <= dc_in;
                        busy      <= 1'b1;
                        clk_cnt   <= 0;
                        state     <= S_SETUP;
                    end
                end

                // ---- SETUP: pull CS low, put first bit on MOSI ----
                S_SETUP: begin
                    cs_out   <= 1'b0;           // activate chip select
                    mosi_out <= shift_reg[7];   // MSB first
                    bit_cnt  <= 4'd0;
                    clk_cnt  <= 0;
                    state    <= S_SHIFT;
                end

                // ---- SHIFT: clock out 8 bits ----
                S_SHIFT: begin
                    clk_cnt <= clk_cnt + 1;

                    if (half_tick) begin
                        // Rising edge of SPI clock — OLED samples MOSI here
                        sclk_out <= 1'b1;
                    end

                    if (clk_tick) begin
                        // Falling edge of SPI clock — we shift next bit
                        sclk_out  <= 1'b0;
                        clk_cnt   <= 0;
                        bit_cnt   <= bit_cnt + 1;

                        if (bit_cnt == 4'd7) begin
                            // All 8 bits sent
                            state <= S_FINISH;
                        end else begin
                            // Shift register left, put next bit on MOSI
                            shift_reg <= {shift_reg[6:0], 1'b0};
                            mosi_out  <= shift_reg[6]; // next MSB
                        end
                    end
                end

                // ---- FINISH: release CS, signal done ----
                S_FINISH: begin
                    cs_out <= 1'b1;
                    busy   <= 1'b0;
                    done   <= 1'b1;
                    state  <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
