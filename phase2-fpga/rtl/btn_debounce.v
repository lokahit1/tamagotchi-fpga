// ============================================================
// btn_debounce.v — Button Debouncer
// ============================================================
// Physical buttons "bounce" — they rapidly toggle between
// 0 and 1 for several milliseconds when pressed or released.
//
// This module samples the button input every ~1ms using a
// shift register. Only when 8 consecutive samples are all
// HIGH does it consider the button "pressed". It then
// outputs a single-cycle pulse on btn_press (edge detect).
//
// At 12 MHz clock:
//   12,000,000 / 12,000 = 1,000 Hz = 1 ms sample interval
//   8 stable samples needed = 8 ms debounce time
// ============================================================

module btn_debounce (
    input  wire clk,        // 12 MHz system clock
    input  wire rst_n,      // active-low reset
    input  wire btn_in,     // raw button input (active HIGH)
    output reg  btn_press   // single-cycle pulse on press
);

    // ---- 1 ms sample timer ----
    reg [13:0] sample_cnt;
    wire sample_tick = (sample_cnt == 14'd11_999);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sample_cnt <= 14'd0;
        else if (sample_tick)
            sample_cnt <= 14'd0;
        else
            sample_cnt <= sample_cnt + 1;
    end

    // ---- 8-bit shift register ----
    // Shifts in the button state every 1 ms
    reg [7:0] shift;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift <= 8'd0;
        else if (sample_tick)
            shift <= {shift[6:0], btn_in};
    end

    // Button is considered "stable HIGH" when all 8 bits are 1
    wire btn_stable = (shift == 8'hFF);

    // ---- Edge detector ----
    // Outputs a single pulse on the rising edge of btn_stable
    reg btn_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_prev  <= 1'b0;
            btn_press <= 1'b0;
        end else begin
            btn_press <= btn_stable & ~btn_prev;  // rising edge
            btn_prev  <= btn_stable;
        end
    end

endmodule
