// ============================================================
// buzzer_pwm.v — Programmable Tone Generator
// ============================================================
// Generates a 50% duty cycle square wave at a frequency
// determined by the freq_div input.
//
// Output frequency = clk_freq / (2 * freq_div)
//
// Examples at 12 MHz clock:
//   freq_div = 13636 → 440 Hz (A4)
//   freq_div = 11364 → 528 Hz (C5)
//   freq_div =  9091 → 660 Hz (E5)
//   freq_div =  6818 → 880 Hz (A5)
//   freq_div =  0    → silence (no toggle)
// ============================================================

module buzzer_pwm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] freq_div,    // 0 = silent
    input  wire        enable,      // master enable
    output reg         pwm_out
);

    reg [15:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 16'd0;
            pwm_out <= 1'b0;
        end else if (!enable || freq_div == 16'd0) begin
            // Silent — hold output low
            counter <= 16'd0;
            pwm_out <= 1'b0;
        end else begin
            if (counter >= freq_div - 1) begin
                counter <= 16'd0;
                pwm_out <= ~pwm_out;   // toggle output
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule
