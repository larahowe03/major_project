module top_level (
	input 	logic 		 CLOCK_50,
	input  	logic        OV7670_PCLK,
	output 	logic        OV7670_XCLK,
	input 	logic        OV7670_VSYNC,
	input  	logic        OV7670_HREF,
	input  	logic [7:0]  OV7670_DATA,
	output 	logic        OV7670_SIOC,
	inout  	wire         OV7670_SIOD,
	output 	logic        OV7670_PWDN,
	output 	logic        OV7670_RESET,
	
	output logic        VGA_HS,
	output logic        VGA_VS,
	output logic [7:0]  VGA_R,
	output logic [7:0]  VGA_G,
	output logic [7:0]  VGA_B,
	output logic        VGA_BLANK_N,
	output logic        VGA_SYNC_N,
	output logic        VGA_CLK,
	
	input logic [3:0] KEY,
	
	output logic zebra_crossing_stop,
	output logic [7:0] LEDG,
	output logic [6:0] HEX0, HEX1, HEX2, HEX3	

);
	logic sys_reset = 1'b0;

	//Camera and VGA PLL
	logic       clk_video;
	logic 		send_camera_config; 
	assign 		send_camera_config = !KEY[2];
	logic			video_pll_locked;
	logic 		config_finished;
	assign 		OV7670_XCLK = clk_video;
	
	video_pll U0(
		 .areset(sys_reset),
		 .inclk0(CLOCK_50),
		 .c0(clk_video),
		 .locked(video_pll_locked)
	);
	
	//Camera programming and data stream
	logic [16:0] wraddress;
	logic [11:0] wrdata;
	logic wren;

	ov7670_controller U1(
		.clk(clk_video),  
		.resend (send_camera_config),
		.config_finished (config_finished),
		.sioc   (OV7670_SIOC),
		.siod   (OV7670_SIOD),
		.reset  (OV7670_RESET),
		.pwdn   (OV7670_PWDN)
	);

	
	ov7670_pixel_capture DUT1 (
		.pclk(OV7670_PCLK),
		.vsync(OV7670_VSYNC),
		.href(OV7670_HREF),
		.d(OV7670_DATA),
		.addr(wraddress),
		.pixel(wrdata),
		.we(wren)
	);



	logic filter_sop_out;
	logic filter_eop_out;
	logic vga_ready;
	logic [11:0] video_data;
	wire vga_blank;  
	wire vga_sync;   


	image_buffer U3
	(
		.data_in(wrdata),
		.rd_clk(clk_video),
		.wr_clk(OV7670_PCLK),
		.ready(vga_ready), 
		.rst(sys_reset),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(filter_sop_out),
		.image_end(filter_eop_out),
		.data_out(video_data)
	);
	assign VGA_CLK = clk_video;
	
	// =========================================================================
	// ********* COMMENT THIS BLOCK OUT FOR ORIGINAL TOP_LEVEL CODE *********
	
	// --------------------------- From image_buffer ---------------------------
	
	// vga_ready comes from vga_driver and is already wired to image_buffer.ready
	// Use it as our "x_valid" (pixel present in active video)
	
	wire pix_valid = vga_ready;  // pulses for visible 640x480 pixels

	// --------- Convert RGB444 --> 8-bit grayscale for edge detection ---------
	
	
	// Simple average (4-bit channels -> 8-bit via replicate & average)
	wire [7:0] gray_r = {video_data[11:8], video_data[11:8]};	// 4->8
	wire [7:0] gray_g = {video_data[7:4],  video_data[7:4]}; 	// 4->8
	wire [7:0] gray_b = {video_data[3:0],  video_data[3:0]};  	// 4->8
	wire [8:0] gray_sum = gray_r + gray_g + gray_b;          	// 9-bit sum
	wire [7:0] gray_px  = gray_sum / 3;                      	// 8-bit

	// ----------------- Sobel-X kernel (signed 8-bit) -----------------
	
//	logic signed [7:0] sobel_x [0:2][0:2];
//	
//	initial begin
//	sobel_x[0][0] = -1; sobel_x[0][1] =  0; sobel_x[0][2] =  1;
//	sobel_x[1][0] = -2; sobel_x[1][1] =  0; sobel_x[1][2] =  2;
//	sobel_x[2][0] = -1; sobel_x[2][1] =  0; sobel_x[2][2] =  1;
//	end

	// signed 8-bit 3x3 Sobel-y kernel
//	localparam logic signed [7:0] SOBEL_Y [0:2][0:2] = '{
//											 '{-8'sd1, -8'sd2, -8'sd1},
//											 '{ 8'sd0,  8'sd0,  8'sd0},
//											 '{ 8'sd1,  8'sd2,  8'sd1}
//										};
//										
	localparam logic signed [7:0] AGGRESSIVE [0:2][0:2] = '{
											 '{-8'sd1, -8'sd1, -8'sd1},
											 '{-8'sd1,  8'sd8, -8'sd1},
											 '{-8'sd1, -8'sd1, -8'sd1}
										};


	// ----------------------- Pattern recognition block -----------------------
	
	// IMPORTANT: set IMG_WIDTH/IMG_HEIGHT = 640x480 here to match pix_valid.
	// (image_buffer doubles the 320x240 source to 640x480; feeding 640x480
	// keeps the detector’s internal (x,y) counters correct.)
	
	logic        pr_y_valid;
	logic [7:0]  pr_y_data;
	logic        crossing_detected;
	logic        detection_valid;
	logic [7:0]  blob_count, show_blob;
	logic [15:0] confidence;

	pattern_recognition #(
	  .IMG_WIDTH (640),
	  .IMG_HEIGHT(480),
	  .KERNEL_H  (3),
	  .KERNEL_W  (3),
	  .W         (8),
	  .W_FRAC    (0)
	) PR (
	  .clk               (clk_video),
	  .rst_n             (~sys_reset),
	  .x_valid           (pix_valid),
	  .x_ready           (),          // <— fix: explicitly unconnected
	  .x_data            (gray_px),
	  .kernel            (AGGRESSIVE),   // <— fix: const aggregate
	  .crossing_detected (crossing_detected),
	  .detection_valid   (detection_valid),
	  .blob_count      (blob_count),
	  .y_valid           (pr_y_valid),
	  .y_ready           (1'b1),
	  .y_data            (pr_y_data)
	);

	always_ff @(posedge clk or negedge rst_n) begin
		if (detection_valid) show_blob <= blob_count;
	end

	display u_display (
		.clk(clk),
    	.value(show_blob),
		.display0(HEX0),
		.display1(HEX1),
		.display2(HEX2),
		.display3(HEX3)
	);

	assign zebra_crossing_stop = crossing_detected & detection_valid;
	assign LEDG[7] = zebra_crossing_stop;  // lights up when zebra detected
	assign LEDG[6:0] = 7'b0;              // keep others off for now

	// --------------- Visualise: choose raw or processed on VGA ---------------
	
	wire use_processed = ~KEY[1];		// toggle with button
	wire [11:0] processed_rgb444 = {pr_y_data[7:4], pr_y_data[7:4], pr_y_data[7:4]};
	wire [11:0] display_pixel = use_processed ? processed_rgb444 : video_data;

	// Drive VGA with selected pixels
	vga_driver U4 (
		.clk(clk_video),
		.rst(sys_reset),
		.pixel(display_pixel),
		.hsync(VGA_HS),
		.vsync(VGA_VS),
		.r(VGA_R),
		.g(VGA_G),
		.b(VGA_B),
		.VGA_BLANK_N(VGA_BLANK_N),
		.VGA_SYNC_N(VGA_SYNC_N),
		.ready(vga_ready)
	);

	// =========================================================================

	
	// =========================================================================
	// ********* UNCOMMENT THIS TO GET THE ORIGINAL *********
	
//	vga_driver U4(
//		 .clk(clk_video), 
//		 .rst(sys_reset),
//		 .pixel(video_data),
//		 .hsync(VGA_HS),
//		 .vsync(VGA_VS),
//		 .r(VGA_R),
//		 .g(VGA_G),
//		 .b(VGA_B),
//	    .VGA_BLANK_N(VGA_BLANK_N),
//	    .VGA_SYNC_N(VGA_SYNC_N),
//		 .ready(vga_ready)
//	);

	// =========================================================================
		
	
endmodule
