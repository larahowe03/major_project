module fft_find_peak #(
    parameter NSamples = 256, // 256 N-points
    parameter W        = 33,   // For 16x2 + 1
    parameter NBits    = $clog2(NSamples)

) (
    input                        clk,
    input                        reset,
    input  [W-1:0]               mag,
    input                        mag_valid,
    output logic [W-1:0]         peak = 0,
    output logic [NBits-1:0]     peak_k = 0,
    output logic                 peak_valid
);

    // Copy & Paste your solution to Lesson 4 fft_find_peak.sv here!
    logic [NBits-1:0] peak_k_raw = 0;
    logic [W-1:0]     peak_raw = 0;
    logic [NBits-1:0] i = 0, k;
    // The FFT k-index is represented by bit-reversing i. This has been done for you.
    // always_comb for (integer j=0; j<NBits; j=j+1) k[j] = i[NBits-1-j]; // bit-reversed index
    assign k = i;

    logic [W-1:0]         peak_temp   = 0;
    logic [NBits-1:0]     peak_k_temp = 0;

    always_ff @(posedge clk) begin : find_peak

        if (reset || !mag_valid) begin
            i <= 0;
            peak_temp <= 0;
            peak_k_temp <= 0;
            peak_valid <= 0;
            peak_raw       <= 0;
            peak_k_raw     <= 0;
        end else begin            
            if (mag > peak_temp && k[NBits-1] == 1'b0) begin
                peak_temp <= mag;
                peak_k_temp <= k;
            end

            if (i == NSamples - 1) begin
                peak_valid <= 1;
                peak_raw <= peak_temp;
                peak_k_raw <= peak_k_temp;
                // reset stuff for next frame?
                i          <= 0;
                peak_temp  <= 0;
                peak_k_temp<= 0;
            end else begin
                i          <= i + 1;
                peak_valid <= 0;
            end
        end
        //TODO Find the peak (maximum) value out of a window of 256 streamed samples (256, actually), streamed in one at a time.
        // Store the corresponding k-index representing that value in 'temp_peak_k'.
        // Ensure 'temp_peak_k' is not negative by ignoring the magnitude input when the k-index is negative (MSB==1).
        
        // Use the counter 'i' to count from 0 to 1023. Then use 'k' as the value to set in 'temp_peak_k'.

        // Set 'peak_valid' to 1'b1 for a single clock cycle when 'i == 1023'.
        // When setting 'peak_valid'=1, also set 'peak' and 'peak_k' to 'temp_peak' and 'temp_peak_k', respectively, when 'i == 1023' (note: this actually ignores the last value, but it has negative k-index, so we ignore it anyway!).

        // Reset all registers when 'i == 1023', in preparation for the next FFT window.
        // Also, reset all registers when 'mag_valid' goes low ('mag' should be a continuous data stream).
        // Also, reset in the usual way if 'reset' is high!
    end

    parameter SMOOTH_SHIFT = 1; // smoothing strength (1/8 new value, 7/8 old)

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            peak_k <= 0;
            peak <= 0;
        end else if (peak_valid) begin
            peak_k <= peak_k + ( $signed(peak_k_raw) - $signed(peak_k) ) >>> SMOOTH_SHIFT;
            peak <= peak + ( $signed(peak_raw) - $signed(peak) ) >>> SMOOTH_SHIFT;
        end
    end

endmodule
