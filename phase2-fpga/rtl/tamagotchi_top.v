// ============================================================
// tamagotchi_top.v — Top-Level Module for iCESugar (iCE40UP5K)
// ============================================================
// This wires all modules together. Port names must match
// the physical constraints in icesugar.pcf.
//
// Note: The iCE40UP5K on iCESugar has NO external clock.
//       We use the internal SB_HFOSC oscillator (see clock_divider.v).
//       Therefore there is no "clk" input pin — the clock is
//       generated internally.
// ============================================================

module tamagotchi_top (
    // ---- OLED Display (SPI) — PMOD 1 ----
    output wire oled_sclk,     // SPI clock
    output wire oled_mosi,     // SPI data
    output wire oled_cs,       // Chip select (active low)
    output wire oled_dc,       // Data/Command
    output wire oled_res,      // Reset (active low)

    // ---- Buttons — PMOD 3 ----
    input  wire btn_left,      // Left button
    input  wire btn_mid,       // Middle button
    input  wire btn_right,     // Right button

    // ---- Buzzer — PMOD 3 ----
    output wire buzzer         // PWM output to piezo
);

    // =========================================================
    //  Internal signals
    // =========================================================
    wire clk;                  // 12 MHz from internal oscillator
    wire tick_1hz;
    wire tick_4hz;

    wire btn_l_clean;
    wire btn_m_clean;
    wire btn_r_clean;

    wire [2:0]  pet_state;
    wire [6:0]  hunger;
    wire [6:0]  happiness;
    wire [6:0]  health;
    wire [2:0]  poop_count;
    wire [1:0]  menu_sel;
    wire        anim_frame;
    wire        show_stats;

    wire [15:0] buzzer_freq;
    wire        buzzer_en;

    wire [7:0]  sprite_addr;
    wire [15:0] sprite_data;

    // ---- Reset generator ----
    // iCE40 has no external reset button, so we generate one
    // using a counter that holds reset low for ~1ms after power-up
    reg [15:0] rst_cnt = 16'd0;
    wire rst_n = (rst_cnt == 16'hFFFF);
    always @(posedge clk) begin
        if (!rst_n)
            rst_cnt <= rst_cnt + 1;
    end

    // =========================================================
    //  Module 1: Clock Divider (internal oscillator)
    // =========================================================
    clock_divider u_clk (
        .clk_12m   (clk),
        .tick_1hz  (tick_1hz),
        .tick_4hz  (tick_4hz)
    );

    // =========================================================
    //  Module 2: Button Debouncers (one per button)
    // =========================================================
    btn_debounce u_btn_l (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_left),
        .btn_press (btn_l_clean)
    );

    btn_debounce u_btn_m (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_mid),
        .btn_press (btn_m_clean)
    );

    btn_debounce u_btn_r (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_right),
        .btn_press (btn_r_clean)
    );

    // =========================================================
    //  Module 3: Game FSM (the brain)
    // =========================================================
    game_fsm u_game (
        .clk        (clk),
        .rst_n      (rst_n),
        .tick_1hz   (tick_1hz),
        .tick_4hz   (tick_4hz),
        .btn_left   (btn_l_clean),
        .btn_mid    (btn_m_clean),
        .btn_right  (btn_r_clean),
        .pet_state  (pet_state),
        .hunger     (hunger),
        .happiness  (happiness),
        .health     (health),
        .poop_count (poop_count),
        .menu_sel   (menu_sel),
        .anim_frame (anim_frame),
        .show_stats (show_stats),
        .buzzer_freq(buzzer_freq),
        .buzzer_en  (buzzer_en)
    );

    // =========================================================
    //  Module 4: Sprite ROM
    // =========================================================
    sprite_rom u_sprites (
        .clk  (clk),
        .addr (sprite_addr),
        .data (sprite_data)
    );

    // =========================================================
    //  Module 5: Display Controller
    //  (reads game state + sprite ROM → drives SPI master)
    //  TODO: implement in display_controller.v
    // =========================================================
    wire [7:0] spi_byte;
    wire       spi_dc;
    wire       spi_start;
    wire       spi_busy;
    wire       spi_done;

    display_controller u_display (
        .clk         (clk),
        .rst_n       (rst_n),
        .pet_state   (pet_state),
        .hunger      (hunger),
        .happiness   (happiness),
        .health      (health),
        .poop_count  (poop_count),
        .menu_sel    (menu_sel),
        .anim_frame  (anim_frame),
        .show_stats  (show_stats),
        .sprite_addr (sprite_addr),
        .sprite_data (sprite_data),
        .spi_byte    (spi_byte),
        .spi_dc      (spi_dc),
        .spi_start   (spi_start),
        .spi_busy    (spi_busy)
    );

    // =========================================================
    //  Module 6: SPI Master
    // =========================================================
    spi_master u_spi (
        .clk       (clk),
        .rst_n     (rst_n),
        .data_in   (spi_byte),
        .dc_in     (spi_dc),
        .start     (spi_start),
        .busy      (spi_busy),
        .done      (spi_done),
        .sclk_out  (oled_sclk),
        .mosi_out  (oled_mosi),
        .cs_out    (oled_cs),
        .dc_out    (oled_dc)
    );

    // =========================================================
    //  OLED Reset: hold low for ~10ms then release
    // =========================================================
    reg [17:0] oled_rst_cnt = 18'd0;
    assign oled_res = (oled_rst_cnt == 18'h3FFFF);
    always @(posedge clk) begin
        if (!oled_res)
            oled_rst_cnt <= oled_rst_cnt + 1;
    end

    // =========================================================
    //  Module 7: Buzzer PWM
    // =========================================================
    buzzer_pwm u_buzzer (
        .clk      (clk),
        .rst_n    (rst_n),
        .freq_div (buzzer_freq),
        .enable   (buzzer_en),
        .pwm_out  (buzzer)
    );

endmodule
