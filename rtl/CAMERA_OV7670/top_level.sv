module top_level (
	// board inputs
	input 	logic		CLOCK_50,
	// input 	logic		rst_n,
	input 	logic [3:0]	KEY,

	// board outputs
	output logic [7:0]	LEDG,
	output logic [6:0]	HEX0, HEX1, HEX2, HEX3,

	// camera inputs and outputs
	input  	logic		OV7670_PCLK,
	output 	logic		OV7670_XCLK,
	input 	logic		OV7670_VSYNC,
	input  	logic		OV7670_HREF,
	input  	logic [7:0]	OV7670_DATA,
	output 	logic		OV7670_SIOC,
	inout  	wire		OV7670_SIOD,
	output 	logic		OV7670_PWDN,
	output 	logic		OV7670_RESET,
	
	// vga inputs and outputs
	output logic        VGA_HS,
	output logic		VGA_VS,
	output logic [7:0]  VGA_R,
	output logic [7:0]  VGA_G,
	output logic [7:0]  VGA_B,
	output logic        VGA_BLANK_N,
	output logic        VGA_SYNC_N,
	output logic        VGA_CLK,
	
	// todo: for state machine
	output logic zebra_crossing_stop  // FIXED: Removed trailing comma
);
	logic rst_n;
   assign rst_n = KEY[0];	// todo: change to rst_n when this is sorted

	// Camera and VGA PLL
	logic clk_video, send_camera_config;
	assign send_camera_config = !KEY[2]; // camera reset

	logic video_pll_locked, config_finished;
	assign OV7670_XCLK = clk_video;
	assign VGA_CLK = clk_video;

	video_pll U0(
		.areset(rst_n),
		.inclk0(CLOCK_50),
		.c0(clk_video),
		.locked(video_pll_locked)
	);
	
	// Camera programming and data stream
	logic [16:0] wraddress;
	logic [11:0] wrdata;
	logic wren;

	ov7670_controller u_ov7670_controller (
		.clk(clk_video),  
		.resend(send_camera_config),
		.config_finished(config_finished),
		.sioc(OV7670_SIOC),
		.siod(OV7670_SIOD),
		.reset(OV7670_RESET),
		.pwdn(OV7670_PWDN)
	);
	
	ov7670_pixel_capture u_ov7670_pixel_capture (
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

	// image buffer between camera and convolution filter
	image_buffer u_image_buffer (
		.data_in(wrdata),
		.rd_clk(clk_video),
		.wr_clk(OV7670_PCLK),
		.ready(vga_ready), 
		.rst(rst_n),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(filter_sop_out),
		.image_end(filter_eop_out),
		.data_out(video_data)
	);
		
	wire pix_valid = vga_ready;  // pulses for visible 640x480 pixels

	// --------- Convert RGB444 --> 8-bit grayscale for edge detection ---------
	
	// Simple average (4-bit channels -> 8-bit via replicate & average)
	wire [7:0] gray_r = {video_data[11:8], video_data[11:8]};	// 4->8
	wire [7:0] gray_g = {video_data[7:4], video_data[7:4]}; 	// 4->8
	wire [7:0] gray_b = {video_data[3:0], video_data[3:0]};  	// 4->8
	wire [8:0] gray_sum = gray_r + gray_g + gray_b;          	// 9-bit sum
	wire [7:0] gray_px  = gray_sum / 3;                      	// 8-bit

	// aggressive edge kernel
	localparam KERNEL_H = 3;
	localparam KERNEL_W = 3;
	localparam IMG_HEIGHT = 240;
	localparam IMG_WIDTH = 320;
	localparam logic signed [7:0] AGGRESSIVE [0:2][0:2] = '{'{-8'sd1, -8'sd1, -8'sd1},
											 				'{-8'sd1,  8'sd8, -8'sd1},
											 				'{-8'sd1, -8'sd1, -8'sd1}};

	// ----------------------- Pattern recognition block -----------------------
		
	logic pr_x_ready;  // ADDED: needed for handshake
	logic pr_y_valid;
	logic pr_y_ready;  // ADDED: needed for handshake
	logic [7:0] pr_y_data;
	logic crossing_detected;
	logic detection_valid;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count;

	// FIXED: Correct instantiation syntax
	pattern_recognition #(
		.IMG_WIDTH(IMG_WIDTH),
		.IMG_HEIGHT(IMG_HEIGHT),
		.KERNEL_H(KERNEL_H),
		.KERNEL_W(KERNEL_W),
		.W(8),
		.W_FRAC(0)
	) u_pattern_recognition (
		.clk(clk_video),           // FIXED: Use clk_video instead of CLOCK_50
		.rst_n(rst_n),
		
		// Input pixel stream (from camera)
		.x_valid(pix_valid),       // FIXED: Connect to actual signal
		.x_ready(pr_x_ready),      // FIXED: Connect to signal
		.x_data(gray_px),          // FIXED: Connect grayscale data
		
		// Edge detection kernel
		.kernel(AGGRESSIVE),
		
		// Detection outputs
		.crossing_detected(crossing_detected),  // FIXED: Proper connection
		.detection_valid(detection_valid),
		.white_count(white_count),
		
		// Optional: edge-detected image output
		.y_valid(pr_y_valid),      // FIXED: Proper connection
		.y_ready(pr_y_ready),      // FIXED: Connect to signal
		.y_data(pr_y_data)         // FIXED: Proper connection
	);

	// FIXED: Connect y_ready (pattern recognition is always ready to output)
	assign pr_y_ready = 1'b1;

	display u_display (
		.clk(clk_video),           // FIXED: Use clk_video
    	.value(white_count),
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
	vga_driver u_vga_driver (
		.clk(clk_video),
		.rst(rst_n),
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
	
endmodule