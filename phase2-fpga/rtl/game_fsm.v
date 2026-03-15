// ============================================================
// game_fsm.v — Tamagotchi Game Logic (Finite State Machine)
// ============================================================
// This is the brain of the pet. It tracks:
//   - Pet state (HAPPY, HUNGRY, SICK, SLEEPING, DEAD)
//   - Hunger counter (0=full, 100=starving)
//   - Happiness counter (0=sad, 100=max)
//   - Health counter (0=dead, 100=perfect)
//   - Poop counter (0=clean, 5=filthy)
//   - Menu selection (FEED, PLAY, CLEAN, STATS)
//   - Animation frame toggle
//
// Inputs: 3 debounced button presses + 1Hz/4Hz ticks
// Outputs: pet state + counters + buzzer frequency
// ============================================================

module game_fsm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,     // 1 Hz from clock divider
    input  wire        tick_4hz,     // 4 Hz for animation
    input  wire        btn_left,     // debounced left button
    input  wire        btn_mid,      // debounced middle button
    input  wire        btn_right,    // debounced right button

    // Pet status outputs
    output reg  [2:0]  pet_state,    // current state enum
    output reg  [6:0]  hunger,       // 0..100
    output reg  [6:0]  happiness,    // 0..100
    output reg  [6:0]  health,       // 0..100
    output reg  [2:0]  poop_count,   // 0..5
    output reg  [1:0]  menu_sel,     // 0=FEED, 1=PLAY, 2=CLEAN, 3=STATS
    output reg         anim_frame,   // toggles for animation
    output reg         show_stats,   // 1 = stats screen active

    // Buzzer control
    output reg  [15:0] buzzer_freq,  // frequency divider (0=silent)
    output reg         buzzer_en     // buzzer enable
);

    // ---- Pet state encoding ----
    localparam ST_HAPPY    = 3'd0;
    localparam ST_HUNGRY   = 3'd1;
    localparam ST_SICK     = 3'd2;
    localparam ST_SLEEPING = 3'd3;
    localparam ST_DEAD     = 3'd4;

    // ---- Buzzer note definitions (12 MHz / (2*freq)) ----
    localparam NOTE_SILENT = 16'd0;
    localparam NOTE_C5     = 16'd11_364;   // 528 Hz
    localparam NOTE_E5     = 16'd9_091;    // 660 Hz
    localparam NOTE_A5     = 16'd6_818;    // 880 Hz
    localparam NOTE_C6     = 16'd5_682;    // 1056 Hz
    localparam NOTE_A4     = 16'd13_636;   // 440 Hz

    // ---- Sound effect timer ----
    reg [19:0] sound_timer;    // counts down to 0
    reg [2:0]  sound_phase;    // phase within a multi-note sound

    // ---- Pseudo-random number generator (LFSR) ----
    // Used for poop timing randomness
    reg [7:0] lfsr = 8'hA5;
    always @(posedge clk) begin
        if (tick_1hz)
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // ---- Seconds counter for slower events ----
    reg [3:0] sec_cnt;    // counts 0..9 for 10-second intervals

    // ---- Animation frame toggle ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            anim_frame <= 1'b0;
        else if (tick_4hz)
            anim_frame <= ~anim_frame;
    end

    // ---- Main game logic ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize pet
            pet_state  <= ST_HAPPY;
            hunger     <= 7'd20;
            happiness  <= 7'd80;
            health     <= 7'd100;
            poop_count <= 3'd0;
            menu_sel   <= 2'd0;
            show_stats <= 1'b0;
            sec_cnt    <= 4'd0;
            buzzer_freq <= NOTE_SILENT;
            buzzer_en  <= 1'b0;
            sound_timer <= 20'd0;
            sound_phase <= 3'd0;
        end else begin

            // ---- Sound timer countdown ----
            if (sound_timer > 0) begin
                sound_timer <= sound_timer - 1;
                if (sound_timer == 1) begin
                    buzzer_freq <= NOTE_SILENT;
                    buzzer_en   <= 1'b0;
                end
            end

            // ==== DEAD STATE: only middle button restarts ====
            if (pet_state == ST_DEAD) begin
                if (btn_mid) begin
                    pet_state  <= ST_HAPPY;
                    hunger     <= 7'd20;
                    happiness  <= 7'd80;
                    health     <= 7'd100;
                    poop_count <= 3'd0;
                    menu_sel   <= 2'd0;
                    show_stats <= 1'b0;
                    // Startup sound
                    buzzer_freq <= NOTE_C5;
                    buzzer_en   <= 1'b1;
                    sound_timer <= 20'd120_000;
                end

            // ==== STATS SCREEN: middle exits ====
            end else if (show_stats) begin
                if (btn_mid) begin
                    show_stats <= 1'b0;
                    buzzer_freq <= NOTE_C6;
                    buzzer_en   <= 1'b1;
                    sound_timer <= 20'd60_000;
                end

            // ==== NORMAL GAMEPLAY ====
            end else begin

                // ---- Button: LEFT = menu left ----
                if (btn_left) begin
                    menu_sel <= (menu_sel == 2'd0) ? 2'd3 : menu_sel - 1;
                    buzzer_freq <= NOTE_C6;
                    buzzer_en   <= 1'b1;
                    sound_timer <= 20'd36_000;  // short click
                end

                // ---- Button: RIGHT = menu right ----
                if (btn_right) begin
                    menu_sel <= (menu_sel == 2'd3) ? 2'd0 : menu_sel + 1;
                    buzzer_freq <= NOTE_C6;
                    buzzer_en   <= 1'b1;
                    sound_timer <= 20'd36_000;
                end

                // ---- Button: MIDDLE = execute action ----
                if (btn_mid) begin
                    case (menu_sel)
                        2'd0: begin // FEED
                            if (hunger > 7'd15)
                                hunger <= hunger - 7'd15;
                            else
                                hunger <= 7'd0;
                            if (happiness < 7'd95)
                                happiness <= happiness + 7'd5;
                            // Feed sound: rising tone
                            buzzer_freq <= NOTE_A5;
                            buzzer_en   <= 1'b1;
                            sound_timer <= 20'd120_000;
                        end
                        2'd1: begin // PLAY
                            if (happiness < 7'd85)
                                happiness <= happiness + 7'd15;
                            else
                                happiness <= 7'd100;
                            if (hunger < 7'd95)
                                hunger <= hunger + 7'd5;
                            // Play sound
                            buzzer_freq <= NOTE_E5;
                            buzzer_en   <= 1'b1;
                            sound_timer <= 20'd120_000;
                        end
                        2'd2: begin // CLEAN
                            if (poop_count > 0) begin
                                poop_count <= 3'd0;
                                buzzer_freq <= NOTE_C6;
                                buzzer_en   <= 1'b1;
                                sound_timer <= 20'd80_000;
                            end
                        end
                        2'd3: begin // STATS
                            show_stats <= 1'b1;
                            buzzer_freq <= NOTE_C6;
                            buzzer_en   <= 1'b1;
                            sound_timer <= 20'd60_000;
                        end
                    endcase
                end

                // ---- Periodic updates on 1 Hz tick ----
                if (tick_1hz) begin
                    sec_cnt <= sec_cnt + 1;

                    // Every tick: hunger increases
                    if (hunger < 7'd100)
                        hunger <= hunger + 7'd1;

                    // Every 2 seconds: happiness decreases
                    if (sec_cnt[0] && happiness > 7'd0)
                        happiness <= happiness - 7'd1;

                    // Random poop (using LFSR)
                    if (lfsr[2:0] == 3'b000 && poop_count < 3'd5)
                        poop_count <= poop_count + 1;

                    // Health effects
                    if (hunger > 7'd80 && health > 7'd0)
                        health <= health - 7'd2;
                    if (poop_count >= 3'd3 && health > 7'd0)
                        health <= health - 7'd1;
                    if (hunger < 7'd40 && poop_count == 3'd0 && health < 7'd100)
                        health <= health + 7'd1;

                    // ---- Update pet state based on stats ----
                    if (health == 7'd0) begin
                        pet_state <= ST_DEAD;
                        // Death sound
                        buzzer_freq <= NOTE_A4;
                        buzzer_en   <= 1'b1;
                        sound_timer <= 20'd600_000;
                    end else if (health < 7'd30) begin
                        pet_state <= ST_SICK;
                    end else if (hunger > 7'd70) begin
                        pet_state <= ST_HUNGRY;
                    end else begin
                        pet_state <= ST_HAPPY;
                    end
                end
            end
        end
    end

endmodule
