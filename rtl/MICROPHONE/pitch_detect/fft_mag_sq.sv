module fft_mag_sq #(
    parameter W = 16
) (
    input                clk,
	 input                reset,
	 input                fft_valid,
    input        [W-1:0] fft_imag,
    input        [W-1:0] fft_real,
    output logic [W*2:0] mag_sq,
	 output logic         mag_valid
);

	// Copy & Paste your solution to Lesson 4 fft_mag_sq.sv here!

    logic signed [W*2-1:0] multiply_stage_real, multiply_stage_imag;
    logic signed [W*2:0]   add_stage;
    
    always_ff @(posedge clk) begin : multiply
        if (reset) begin
            multiply_stage_imag <= '0;
            multiply_stage_real <= '0;
        end else begin
            multiply_stage_imag <= signed'(fft_imag) * signed'(fft_imag);
            multiply_stage_real <= signed'(fft_real) * signed'(fft_real);
        end
    end

    always_ff @(posedge clk) begin : add
        if (reset) begin
            add_stage <= '0;        
        end else begin
            add_stage <= multiply_stage_imag + multiply_stage_real;
        end
    end

    logic [1:0] valid_sr;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_sr <= 2'b0;
        end else begin
            valid_sr <= {valid_sr[0], fft_valid}; // shift one digit left
        end
    end


    assign mag_sq    = add_stage;
    assign mag_valid = valid_sr[1];

endmodule
