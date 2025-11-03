module top_level (
	// board inputs
	input 	logic		CLOCK_50,
	input 	logic [3:0]	KEY,
	input 	logic [17:0]	SW,

	// board outputs
	output logic [7:0]	LEDG,
	output logic [17:0]	LEDR,
	output logic [6:0]	HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,

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

	// ========================================================================
	// USE BLUE CHANNEL ONLY (4-bit -> 8-bit)
	// ========================================================================
	
	wire [7:0] gray_px = {video_data[3:0], video_data[3:0]};  // Blue channel replicated
	
	// For display, create grayscale RGB444 from blue channel
	wire [11:0] grayscale_rgb444 = {gray_px[7:4], gray_px[7:4], gray_px[7:4]};

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
	logic pr_y_valid_bw;
	logic pr_y_ready;
	logic [7:0] pr_y_data;
	logic crossing_detected;
	logic detection_valid;
	logic [7:0] stripe_count;


	logic valid_to_read, capturing;

	assign LEDG[0] = capturing;
	assign LEDG[1] = valid_to_read;

    logic [7:0] pr_y_data_bw;
    logic white_count_valid;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels;
	pattern_recognition #(
		.IMG_WIDTH(IMG_WIDTH),
		.IMG_HEIGHT(IMG_HEIGHT),
		.KERNEL_H(KERNEL_H),
		.KERNEL_W(KERNEL_W),
		.W(8),
		.W_FRAC(0)
	) u_pattern_recognition (
		.clk(clk_video),
		.rst_n(rst_n),
		
		// Input pixel stream (BLUE CHANNEL ONLY)
		.x_valid(pix_valid),
		.x_ready(pr_x_ready),
		.x_data(gray_px),  // Blue channel as 8-bit grayscale
		
		// Edge detection kernel
		.kernel(AGGRESSIVE),
		.valid_to_read(valid_to_read),
		.capturing(capturing),
		
		// Edge-detected image output
		.y_valid(pr_y_valid),
		.y_valid_bw(pr_y_valid_bw),
		.y_ready(pr_y_ready),
		.y_data(pr_y_data),
		.y_data_bw(pr_y_data_bw),

		.num_white_edge_pixels(num_white_edge_pixels),
		.num_white_threshold_pixels(num_white_threshold_pixels),
		.white_count_valid(white_count_valid),

		// observable outputs
		.num_threshold_pixels_fulfilled(LEDR[0]),
		.num_edge_pixels_fulfilled(LEDR[1]),
		.num_connected_edge_instances_fulfilled(LEDR[2])
	);

	// Pattern recognition is always ready to output
	assign pr_y_ready = 1'b1;

    // ========================================================================
	// PIXEL COUNT CAPTURE AND DISPLAY
	// ========================================================================

	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels_show;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels_show;

	always_ff @(posedge clk_video or negedge rst_n) begin
		if (!rst_n) begin
			num_white_edge_pixels_show <= '0;
			num_white_threshold_pixels_show <= '0;
		end else begin
			// FIXED: Update on every white_count_valid pulse (removed SW[0] condition)
			if (white_count_valid) begin
				num_white_edge_pixels_show <= num_white_edge_pixels;
				num_white_threshold_pixels_show <= num_white_threshold_pixels;
			end
		end
	end

	// Display on 7-segment (lower 16 bits only - displays 0-65535)
	display u_display1 (
		.clk(clk_video),
		.value(num_white_edge_pixels_show[15:0]),  // Show lower 16 bits
		.display0(HEX0),
		.display1(HEX1),
		.display2(HEX2),
		.display3(HEX3)
	);

	display u_display2 (
		.clk(clk_video),
		.value(num_white_threshold_pixels_show[15:0]),  // Show lower 16 bits
		.display0(HEX4),
		.display1(HEX5),
		.display2(HEX6),
		.display3(HEX7)
	);
	

	// Zebra crossing detection output
	assign zebra_crossing_stop = crossing_detected & detection_valid;
	assign LEDG[7] = zebra_crossing_stop;
	
	// Show detection status on other LEDs
	assign LEDG[6] = detection_valid;

	// --------------- Visualise: choose thresholded or convolved on VGA ---------------
	
	wire use_convolved = ~KEY[1];  // toggle with button
	wire [11:0] convolved_rgb444 = {pr_y_data[7:4], pr_y_data[7:4], pr_y_data[7:4]};
	wire [11:0] thresholded_rgb444 = {pr_y_data_bw[7:4], pr_y_data_bw[7:4], pr_y_data_bw[7:4]};
	wire [11:0] display_pixel = use_convolved ? convolved_rgb444 : thresholded_rgb444;
	wire [11:0] true_display_pixel = SW[0] ? display_pixel : grayscale_rgb444;

	// Drive VGA with selected pixels
	vga_driver u_vga_driver (
		.clk(clk_video),
		.rst(~rst_n),
		.pixel(true_display_pixel),
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