module microphone_top_level #(
	parameter int DE1_SOC = 1 // !!!IMPORTANT: Set this to 1 for DE1-SoC or 0 for DE2-115
) (
	input       CLOCK_50,     // 50 MHz only used as input to the PLLs.

	// DE1-SoC I2C to WM8731:
	output	   FPGA_I2C_SCLK,
	inout       FPGA_I2C_SDAT,
	// DE2-115 I2C to WM8731:
	output      I2C_SCLK,
	inout       I2C_SDAT,

	// Whistle Detection Output
	output logic whistle_detected,

	output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [15:0] LEDR,
	input  [3:0] KEY,
	input	 AUD_ADCDAT,
	input    AUD_BCLK,     // 3.072 MHz clock from the WM8731
	output   AUD_XCK,      // 18.432 MHz sampling clock to the WM8731
	input    AUD_ADCLRCK
);
	localparam W        = 16;   //NOTE: To change this, you must also change the Twiddle factor initialisations in r22sdf/Twiddle.v. You can use r22sdf/twiddle_gen.pl.
	localparam NSamples = 256; //NOTE: To change this, you must also change the SdfUnit instantiations in r22sdf/FFT.v accordingly.

	logic i2c_clk; i2c_pll i2c_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(i2c_clk)); // generate 20 kHz clock
	logic adc_clk; adc_pll adc_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(adc_clk)); // generate 18.432 MHz clock
	logic audio_clk; assign audio_clk = AUD_BCLK; // 3.072 MHz clock from the WM8731

	assign AUD_XCK = adc_clk; // The WM8731 needs a 18.432 MHz sampling clock from the FPGA. AUD_BCLK is then 1/6th of this.

	// Board-specific I2C connections:
	generate
		if (DE1_SOC) begin : DE1_SOC_BOARD
			set_audio_encoder set_codec_de1_soc (.i2c_clk(i2c_clk), .I2C_SCLK(FPGA_I2C_SCLK), .I2C_SDAT(FPGA_I2C_SDAT)); // Connected to the DE1-SoC I2C pins
			assign I2C_SCLK = 1'b1;  // Tie-off unused DE2-115 I2C pins
			assign I2C_SDAT = 1'bZ;
		end else begin : DE2_115_BOARD
			set_audio_encoder set_codec_de2_115 (.i2c_clk(i2c_clk), .I2C_SCLK(I2C_SCLK), .I2C_SDAT(I2C_SDAT)); // Connected to the DE2-115 I2C pins
			assign FPGA_I2C_SCLK = 1'b1; // Tie-off unused DE1-SoC I2C pins
			assign FPGA_I2C_SDAT = 1'bZ;
		end
	endgenerate
	// The above modules configure the WM8731 audio codec for microphone input. They are in set_audio_encoder.v and use the i2c_master module in i2c_master.sv.

	logic reset; assign reset = ~KEY[0];

	// Audio Input
	logic [W-1:0]              audio_input_data;
	logic                      audio_input_valid;
	mic_load #(.N(W)) u_mic_load (
		.adclrc(AUD_ADCLRCK),
		.bclk(AUD_BCLK),
		.adcdat(AUD_ADCDAT),
		.sample_data(audio_input_data),
		.valid(audio_input_valid)
	);
	
    // getting the absolute value of the audio input    
    logic [15:0] abs_audio;
    always_comb begin
        if (audio_input_data[15])
            abs_audio = (~audio_input_data + 1);
        else
            abs_audio = audio_input_data;
	end

    // the abs_audio to show magnitude on the LEDs
    assign LEDR[15:0] = abs_audio[15:0];
	
	logic [$clog2(NSamples)-1:0] pitch_output_data;
	logic whistle_detect_pulse;
	
	fft_pitch_detect #(.W(W), .NSamples(NSamples)) u_fft_pitch_detect (
	    .audio_clk(audio_clk),
	    .fft_clk(adc_clk), // Reuse ADC sampling clock for the FFT pipeline.
	    .reset(reset),
	    .audio_input_data(audio_input_data),
	    .audio_input_valid(audio_input_valid),
	    .pitch_output_data(pitch_output_data),
	    .pitch_output_valid(),
		.whistle_detected(whistle_detect_pulse)
	);

	// This is just to stretch the whistle detection LED output for visibility
	logic [23:0] pulse_counter;
	localparam int STRETCH_CYCLES = 12_500_000; // ~0.25s

	always_ff @(posedge CLOCK_50 or posedge reset) begin
		if (reset) begin
			pulse_counter <= 0;
			whistle_detected <= 1'b0;
		end
		else begin
			if (whistle_detect_pulse) begin
				// start stretch timer whenever pulse occurs
				pulse_counter <= STRETCH_CYCLES;
				whistle_detected <= 1'b1;
			end 
			else if (pulse_counter > 0) begin
				pulse_counter <= pulse_counter - 1;
				whistle_detected <= 1'b1;
			end 
			else begin
				whistle_detected <= 1'b0;
			end
		end
	end

	// Display (for peak `k` FFT index displayed on HEX0-HEX3):
	display u_display (
		.clk(adc_clk),
		.value(pitch_output_data),
		.display0(HEX0),
		.display1(HEX1),
		.display2(HEX2),
		.display3(HEX3)
	);

endmodule


