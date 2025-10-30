module buzzer (
    input  logic        CLOCK_50,   // 50 MHz clock on DE2-115
    input  logic [3:0]  KEY,        // push-buttons (active-low)
    inout  logic [35:0] GPIO,	        // connect GPIO[3] → buzzer S
	 output  logic [17:0] LEDR
);
    // --- Internal signals ---
    logic [25:0] dur_cnt = 0;       // duration counter
    logic [15:0] tone_cnt = 0;      // tone frequency counter
    logic trigger_prev = 0;
    logic active = 0;
    logic tone = 0;
    logic trigger;

    // Button press = 1 (active-low button)
    assign trigger = !KEY[0];

    always_ff @(posedge CLOCK_50) begin
        trigger_prev <= trigger;

        // Detect rising edge of button press
        if (trigger && !trigger_prev) begin
            active   <= 1;
            dur_cnt  <= 0;
            tone_cnt <= 0;
            tone     <= 0;
        end 
        else if (active) begin
            // Beep for 1 second (50 MHz × 1 s)
            if (dur_cnt >= 50_000_000) begin
                active <= 0;
                tone   <= 0;
            end 
            else begin
                dur_cnt <= dur_cnt + 1;

                // Toggle every 25 000 cycles → 1 kHz square wave
                if (tone_cnt >= 25_000) begin
                    tone_cnt <= 0;
                    tone <= ~tone;
                end 
                else begin
                    tone_cnt <= tone_cnt + 1;
                end
            end
        end 
        else begin
            tone <= 0;  // silent when inactive
        end
    end

    // Output the tone only when active
    assign GPIO[5] = tone;
	 assign LEDR[0] = tone;

endmodule
