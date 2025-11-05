
module vga (
	beat_pulse_beat_pulse,
	bpm_estimate_bpm_estimate,
	clk_clk,
	reset_reset_n,
	vga_CLK,
	vga_HS,
	vga_VS,
	vga_BLANK,
	vga_SYNC,
	vga_R,
	vga_G,
	vga_B);	

	input	[1:0]	beat_pulse_beat_pulse;
	input	[8:0]	bpm_estimate_bpm_estimate;
	input		clk_clk;
	input		reset_reset_n;
	output		vga_CLK;
	output		vga_HS;
	output		vga_VS;
	output		vga_BLANK;
	output		vga_SYNC;
	output	[7:0]	vga_R;
	output	[7:0]	vga_G;
	output	[7:0]	vga_B;
endmodule
