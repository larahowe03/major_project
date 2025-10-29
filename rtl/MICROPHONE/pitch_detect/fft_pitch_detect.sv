module fft_pitch_detect # (
    parameter int NSamples = 256,
	parameter int W = 16,
	parameter int UPPER_WHISTLE = 60,
	parameter int LOWER_WHISTLE = 45,
	parameter int UPPER_BEEP = 20,
	parameter int LOWER_BEEP = 10
) (
    input logic audio_clk,
	 input logic fft_clk,
	 input logic reset,
	 
	 input logic [W-1:0] audio_input_data,
	 input logic audio_input_valid,
	 
	 output logic [$clog2(NSamples)-1:0] pitch_output_data,
	 output logic pitch_output_valid,
	 output logic whistle_detected,
	 output logic beep_detected,
	 output logic [7:0] peak_display
);
	// DSP Chain
	// Input clock domain is audio_clk (3.072 MHz). This is AUD_BCLK, the 3.072 MHz clock from the WM8731.
	//  - Decimate by x4 (48kHz sample rate --> 12 kHz decimated sample rate)
	//  - Windowing (Triangle window)
	//  - *FFT Input Buffer (Input). Crosses clock domains audio_clk -> fft_clk.
	// FFT clock domain uses fft_clk (18.432 MHz), which is reusing the adc_clk, see adc_pll in top_level.
	//  - *FFT Input Buffer (Output).
	//  - FFT
	//  - Magnitude Squared
	//  - Find Peak
	//  - FFT Output Buffer (for SignalTap debugging)

	logic [W-1:0] 			decimated_data;
	logic                   decimated_valid;
	decimate #(.W(W), .DECIMATE_FACTOR(4)) u_decimate (
		.clk(audio_clk),
		.x_data(audio_input_data),
		.x_valid(audio_input_valid),
		.x_ready(),
		.y_data(decimated_data),
		.y_valid(decimated_valid),
		.y_ready(1'b1)  // Never need to assert back-pressure given 48 kHz << 18.432 MHz.
	);

	logic [W-1:0] 			   windowed_data;
	logic                      windowed_valid;
	window_function #(.W(W), .NSamples(NSamples)) u_window_function (
		.clk(audio_clk),
		.reset(reset),
		.x_valid(decimated_valid),
		.x_ready(),
		.x_data(decimated_data),
		.y_valid(windowed_valid),
		.y_ready(1'b1),  // Never need to assert back-pressure given 48 kHz << 18.432 MHz.
		.y_data(windowed_data)
	);

	logic           di_en;  //  FFT Input Data Enable
	logic   [W-1:0] di_re;  //  FFT Input Data (Real)
	logic   [W-1:0] di_im;  //  FFT Input Data (Imag)
	fft_input_buffer #(.W(W), .NSamples(NSamples)) u_fft_input_buffer (
		.reset(reset),
		.audio_clk(audio_clk),
		.audio_input_data(windowed_data),
		.audio_input_valid(windowed_valid),
		.audio_input_ready(),   // Never need to assert back-pressure given 48 kHz << 18.432 MHz.
		// Clock domain changes here (audio_clk -> fft_clk)
		.clk(fft_clk),
		.fft_input(di_re),
		.fft_input_valid(di_en)
	);
	assign  di_im = 0;      // FFT Input: No imaginary parts (audio signal is purely real input).

	logic           do_en;  //  FFT Output Data Enable
	logic   [W-1:0] do_re;  //  FFT Output Data (Real)
	logic   [W-1:0] do_im;  //  FFT Output Data (Imag) (Note, we get imaginary output, despite the input being only real)
	FFT #(.WIDTH(W)) u_fft_ip (
		.clock(fft_clk), 
		.reset(reset), 
		.di_en(di_en), 
		.di_re(di_re), 
		.di_im(di_im), 
		.do_en(do_en), 
		.do_re(do_re), 
		.do_im(do_im)
	);

	logic           mag_valid;
	logic   [W*2:0] mag_sq;
	fft_mag_sq #(.W(W)) u_fft_mag_sq (
		.clk(fft_clk), 
		.reset(reset), 
		.fft_valid(do_en), 
		.fft_imag(do_im), 
		.fft_real(do_re), 
		.mag_sq(mag_sq),
		.mag_valid(mag_valid)
	);

	logic [$clog2(NSamples)-1:0] pitch_pulse;

	logic [32:0] peak;
	logic [32:0] peak_pulse;
	
	fft_find_peak #(.W(W*2+1),.NSamples(NSamples)) u_fft_find_peak (
		.clk(fft_clk), 
		.reset(reset), 
		.mag(mag_sq), 
		.mag_valid(mag_valid), 
		.peak(peak_pulse), 
		.peak_k(pitch_pulse), 
		.peak_valid(pitch_output_valid)
	);

	assign peak_display = peak >> (W-8); // Scale down for display purposes

	localparam int PEAK_THRESHOLD = 100; // decimal threshold for valid pitch

	always_ff @(posedge fft_clk or posedge reset) begin
		if (reset) begin
			pitch_output_data <= '0;
			peak <= '0;
		end else if (pitch_output_valid) begin
			// only update if peak_display >= threshold
			if (peak_display >= PEAK_THRESHOLD) begin
				pitch_output_data <= pitch_pulse;
			end else begin
				pitch_output_data <= '0;  // silence -> zero bin
			end
			peak <= peak_pulse;
		end
	end
	
	always_ff @(posedge fft_clk or posedge reset) begin
		if (reset) begin
			whistle_detected <= 1'b0;
			beep_detected <= 1'b0;
		end else begin
			// Output 1 for a single clock when valid & within threshold
			if (pitch_output_valid && ( UPPER_WHISTLE > pitch_output_data ) && (pitch_output_data > LOWER_WHISTLE))
				whistle_detected <= 1'b1;
			else
				whistle_detected <= 1'b0;

			if (pitch_output_valid && ( UPPER_BEEP > pitch_output_data ) && (pitch_output_data > LOWER_BEEP))
				beep_detected <= 1'b1;
			else
				beep_detected <= 1'b0;
		end
	end

	// Output buffer is used only for SignalTap debugging purposes:
	(* preserve *) (* noprune *) logic [W*2:0] readout_data;
	fft_output_buffer #(.W(W*2+1),.NSamples(NSamples)) u_fft_output_buffer (
		.clk(fft_clk), 
		.reset(reset), 
		.mag(mag_sq), 
		.mag_valid(mag_valid),
		.readout_data(readout_data)
	);

endmodule
