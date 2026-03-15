// ============================================================
// clock_divider.v — Clock generation for iCE40UP5K
// ============================================================
// The iCE40UP5K has NO external clock crystal on the iCESugar.
// Instead, we use the built-in SB_HFOSC (48 MHz) primitive
// and divide it down to get the clocks we need:
//
//   clk_12m   — 12 MHz system clock (HFOSC div 4)
//   tick_1hz  — 1 Hz pulse (pet state updates)
//   tick_4hz  — 4 Hz pulse (animation frames)
// ============================================================

module clock_divider (
    output wire clk_12m,      // 12 MHz system clock
    output reg  tick_1hz,     // 1 pulse per second
    output reg  tick_4hz      // 4 pulses per second
);

    // ---- Internal 48 MHz oscillator ----
    // SB_HFOSC is a Lattice iCE40 primitive.
    // CLKHF_DIV = "0b10" means divide by 4 → 12 MHz output.
    //   "0b00" = 48 MHz
    //   "0b01" = 24 MHz
    //   "0b10" = 12 MHz
    //   "0b11" =  6 MHz
    SB_HFOSC #(
        .CLKHF_DIV ("0b10")   // 48 MHz / 4 = 12 MHz
    ) u_hfosc (
        .CLKHFPU (1'b1),       // power up
        .CLKHFEN (1'b1),       // enable
        .CLKHF   (clk_12m)    // 12 MHz output
    );

    // ---- 1 Hz tick generator ----
    // 12,000,000 / 1 = 12,000,000 counts per tick
    reg [23:0] cnt_1hz = 24'd0;
    always @(posedge clk_12m) begin
        tick_1hz <= 1'b0;
        if (cnt_1hz == 24'd11_999_999) begin
            cnt_1hz  <= 24'd0;
            tick_1hz <= 1'b1;
        end else begin
            cnt_1hz <= cnt_1hz + 1;
        end
    end

    // ---- 4 Hz tick generator ----
    // 12,000,000 / 4 = 3,000,000 counts per tick
    reg [21:0] cnt_4hz = 22'd0;
    always @(posedge clk_12m) begin
        tick_4hz <= 1'b0;
        if (cnt_4hz == 22'd2_999_999) begin
            cnt_4hz  <= 22'd0;
            tick_4hz <= 1'b1;
        end else begin
            cnt_4hz <= cnt_4hz + 1;
        end
    end

endmodule
