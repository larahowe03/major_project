`timescale 1ns/1ps

module image_buffer_tb;

	// ----------------------------------------------------
	// Parameters
	// ----------------------------------------------------
	localparam int N_COLS = 64; 	// Decreased size for simulation
	localparam int N_ROWS = 48;		// faster run
	localparam int TOTAL_PIXELS = N_COLS * N_ROWS;

	// ----------------------------------------------------
	// Signals
	// ----------------------------------------------------
	logic         rd_clk;
	logic         wr_clk;
	logic         rst;
	logic [11:0]  data_in;
	logic [16:0]  wraddress;
	logic         wren;
	logic         image_start;
	logic         image_end;
	logic [11:0]  data_out;
	logic         vga_ready;  
	logic         VGA_HS;
	logic         VGA_VS;
	logic [7:0]   VGA_R;
	logic [7:0]   VGA_G;
	logic [7:0]   VGA_B;

	// ----------------------------------------------------
	// DUT Instantiation
	// ----------------------------------------------------
	image_buffer DUT1 (
		.data_in(data_in),
		.rd_clk(rd_clk),
		.wr_clk(wr_clk),
		.ready(vga_ready), 
		.rst(rst),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(image_start),
		.image_end(image_end),
		.data_out(data_out)
	);

	vga_driver DUT2 (
		.clk(rd_clk), 
		.rst(rst),
		.pixel(data_out),
		.hsync(VGA_HS),
		.vsync(VGA_VS),
		.r(VGA_R),
		.g(VGA_G),
		.b(VGA_B),
		.ready(vga_ready)
	);

	// ----------------------------------------------------
	// Clock generation (25 MHz)
	// ----------------------------------------------------
	initial rd_clk = 0;
	initial wr_clk = 0;
	always #20 rd_clk = ~rd_clk;
	always #20 wr_clk = ~wr_clk;

	// ----------------------------------------------------
	// Simulated frame control (since image_start/end are outputs
	// that the VGA might expect to see, we fake a simple frame)
	// ----------------------------------------------------
	initial begin
		image_start = 0;
		image_end   = 0;
		wait(!rst);
		#200;
		image_start = 1;  #100; image_start = 0;
		#5000;
		image_end   = 1;  #100; image_end   = 0;
	end

	// ----------------------------------------------------
	// Test sequence
	// ----------------------------------------------------
	initial begin
		$display("----- Starting image_buffer_tb simulation -----");
		rst = 1;
		wren = 0;
		wraddress = 0;
		data_in = 0;

		// Hold reset for a few cycles
		repeat (5) @(posedge wr_clk);
		rst = 0;

		// Write a few pixels
		$display("[%t] Writing %0d pixels...", $time, TOTAL_PIXELS);
		for (int i = 0; i < TOTAL_PIXELS; i++) begin
			@(posedge wr_clk);
			wren      = 1;
			wraddress = i;
			data_in   = i[11:0];
		end
		
		wren = 0;
		$display("[%t] Finished writing pixels.", $time);

		// Let VGA run a little bit
		repeat (100000) @(posedge rd_clk);
		$display("[%t] Simulation complete. Stopping now.", $time);
		$finish;
		
	end

endmodule
