module top_level (
	// board inputs
	input 	logic		CLOCK_50,
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
	
	// for state machine
	output logic zebra_crossing_stop
);
	logic rst_n;
	assign rst_n = KEY[0];

	// Camera and VGA PLL
	logic clk_video, send_camera_config;
	assign send_camera_config = !KEY[2]; // camera reset

	logic video_pll_locked, config_finished;
	assign OV7670_XCLK = clk_video;
	assign VGA_CLK = clk_video;

	video_pll U0(
		.areset(~rst_n),
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

	// image buffer between camera and convolution filter
	image_buffer u_image_buffer (
		.data_in(wrdata),
		.rd_clk(clk_video),
		.wr_clk(OV7670_PCLK),
		.ready(vga_ready), 
		.rst(~rst_n),
		.wren(wren),
		.wraddress(wraddress), 
		.image_start(filter_sop_out),
		.image_end(filter_eop_out),
		.data_out(video_data)
	);
		
	wire pix_valid = vga_ready;

	// --------- Convert RGB444 --> 8-bit grayscale for edge detection ---------
	
	// Simple average (4-bit channels -> 8-bit via replicate & average)
	wire [7:0] gray_r = {video_data[11:8], video_data[11:8]};
	wire [7:0] gray_g = {video_data[7:4], video_data[7:4]};
	wire [7:0] gray_b = {video_data[3:0], video_data[3:0]};
	wire [8:0] gray_sum = gray_r + gray_g + gray_b;
	wire [7:0] gray_px  = gray_sum / 3;

	// aggressive edge kernel
	localparam KERNEL_H = 3;
	localparam KERNEL_W = 3;
	localparam IMG_HEIGHT = 480;
	localparam IMG_WIDTH = 640;
	localparam logic signed [7:0] AGGRESSIVE [0:2][0:2] = '{
		'{-8'sd1, -8'sd1, -8'sd1},
		'{-8'sd1,  8'sd8, -8'sd1},
		'{-8'sd1, -8'sd1, -8'sd1}
	};

	// ----------------------- Pattern recognition block -----------------------
		
	logic pr_x_ready;
	logic pr_y_valid;
	logic pr_y_ready;
	logic [7:0] pr_y_data;
	logic crossing_detected;
	logic detection_valid;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] white_count;
	logic [7:0] blob_count;
	logic [31:0] blob_areas [0:255];

	// Example: Trigger capture with a button
    assign capture_trigger = ~KEY[3];  // Press KEY[3] to capture frame

	logic capture_complete, capturing;

	assign LEDG[0] = capturing;
	assign LEDG[1] = capture_complete;
	assign LEDG[2] = capture_trigger;
	pattern_recognition #(
		.IMG_WIDTH(IMG_WIDTH),
		.IMG_HEIGHT(IMG_HEIGHT),
		.KERNEL_H(KERNEL_H),
		.KERNEL_W(KERNEL_W),
		.W(8),
		.W_FRAC(0),
		.MIN_BLOB_AREA(500),      // Minimum blob size
		.MAX_BLOB_AREA(50000),    // Maximum blob size
		.MIN_BLOBS(3)             // Need at least 3 blobs for zebra
	) u_pattern_recognition (
		.clk(clk_video),
		.rst_n(rst_n),
		
		// Input pixel stream (from camera)
		.x_valid(pix_valid),
		.x_ready(pr_x_ready),
		.x_data(gray_px),
		
		// Edge detection kernel
		.kernel(AGGRESSIVE),
		.capture_trigger(capture_trigger),
		.capture_complete(capture_complete),
		.capturing(capturing),
		
		// Detection outputs
		.crossing_detected(crossing_detected),
		.detection_valid(detection_valid),
		.white_count(white_count),
		.blob_count(blob_count),
		.blob_areas(blob_areas),
		
		// Edge-detected image output
		.y_valid(pr_y_valid),
		.y_ready(pr_y_ready),
		.y_data(pr_y_data)
	);

	// Pattern recognition is always ready to output
	assign pr_y_ready = 1'b1;

	// Display blob count on 7-segment displays
	display u_display (
		.clk(clk_video),
		.value(blob_count),
		.display0(HEX0),
		.display1(HEX1),
		.display2(HEX2),
		.display3(HEX3)
	);

	// Zebra crossing detection output
	assign zebra_crossing_stop = crossing_detected & detection_valid;
	assign LEDG[7] = zebra_crossing_stop;  // LED lights up when zebra detected
	
	// Show detection status on other LEDs
	assign LEDG[6] = detection_valid;      // Detection cycle complete
//	assign LEDG[5:0] = blob_count[5:0];    // Show blob count on LEDs

	// --------------- Visualise: choose raw or processed on VGA ---------------
	
	wire use_processed = ~KEY[1];  // toggle with button
	wire [11:0] processed_rgb444 = {pr_y_data[7:4], pr_y_data[7:4], pr_y_data[7:4]};
	wire [11:0] display_pixel = use_processed ? processed_rgb444 : video_data;

	// Drive VGA with selected pixels
	vga_driver u_vga_driver (
		.clk(clk_video),
		.rst(~rst_n),
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