module top_level_vision (
	// board inputs
	input 	logic		CLOCK_50,
	input 	logic [3:0]	KEY,
	input 	logic [17:0]	SW,

	// board outputs
//	output logic [7:0]	LEDG,
	output logic [17:0]	LEDR,
//	output logic [6:0]	HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,

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
	assign send_camera_config = !KEY[2];

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
	// Parameters
	// ========================================================================
	
	localparam IMG_HEIGHT = 480;
	localparam IMG_WIDTH = 640;
	localparam KERNEL_H = 3;
	localparam KERNEL_W = 3;
	
	// ========================================================================
	// USE BLUE CHANNEL ONLY (4-bit -> 8-bit)
	// ========================================================================
	
	wire [7:0] gray_px = {video_data[3:0], video_data[3:0]};

	localparam logic signed [7:0] AGGRESSIVE [0:2][0:2] = '{
		'{-8'sd1, -8'sd1, -8'sd1},
		'{-8'sd1,  8'sd8, -8'sd1},
		'{-8'sd1, -8'sd1, -8'sd1}
	};

	// ========================================================================
	// Pattern recognition block
	// ========================================================================
	
	logic pr_x_ready;
	logic pr_y_valid;
	logic pr_y_valid_bw;
	logic pr_y_ready;
	logic [7:0] pr_y_data;
	logic [7:0] pr_y_data_bw;
	logic white_count_valid;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels;
	
	logic valid_to_read, capturing;
	
	// Bounding box and components
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_components;
	logic [$clog2(IMG_HEIGHT)-1:0] edge_top;
	logic [$clog2(IMG_HEIGHT)-1:0] edge_bottom;
	logic [$clog2(IMG_WIDTH)-1:0] edge_left;
	logic [$clog2(IMG_WIDTH)-1:0] edge_right;
	logic [$clog2(IMG_HEIGHT)-1:0] threshold_bottom;
	logic close_to_crossing_edge;
	logic close_to_crossing_threshold;
	logic components_valid;

	pattern_recognition #(
		.IMG_WIDTH(IMG_WIDTH),
		.IMG_HEIGHT(IMG_HEIGHT),
		.KERNEL_H(KERNEL_H),
		.KERNEL_W(KERNEL_W),
		.W(8),
		.W_FRAC(0),
		.MAX_EDGES(1024)
	) u_pattern_recognition (
		.clk(clk_video),
		.rst_n(rst_n),
		
		.x_valid(pix_valid),
		.x_ready(pr_x_ready),
		.x_data(gray_px),
		
		.kernel(AGGRESSIVE),
		.valid_to_read(valid_to_read),
		.capturing(capturing),
		
		.y_valid(pr_y_valid),
		.y_valid_bw(pr_y_valid_bw),
		.y_ready(pr_y_ready),
		.y_data(pr_y_data),
		.y_data_bw(pr_y_data_bw),

		.num_white_edge_pixels(num_white_edge_pixels),
		.num_white_threshold_pixels(num_white_threshold_pixels),
		.white_count_valid(white_count_valid),

		.num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
		.num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
		.num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
		.lowest_edge_position_fulfilled(lowest_edge_position_fulfilled),
		
		// Bounding box and components
		.edge_top(edge_top),
		.edge_bottom(edge_bottom),
		.edge_left(edge_left),
		.edge_right(edge_right),
		.threshold_bottom(threshold_bottom),
		.close_to_crossing_edge(close_to_crossing_edge),
		.close_to_crossing_threshold(close_to_crossing_threshold),
		.num_connected_components(num_connected_components),
		.components_valid(components_valid)
	);
	
	logic num_threshold_pixels_fulfilled;
	logic num_edge_pixels_fulfilled;
	logic num_connected_edge_instances_fulfilled;
	logic lowest_edge_position_fulfilled;

//	assign LEDR[0] = num_threshold_pixels_fulfilled;
//	assign LEDR[1] = num_edge_pixels_fulfilled;
//	assign LEDR[2] = num_connected_edge_instances_fulfilled;
//	assign LEDR[3] = lowest_edge_position_fulfilled;
//	assign LEDR[4] = close_to_crossing_edge_show;
//	assign LEDR[5] = close_to_crossing_threshold_show;
	
	assign zebra_crossing_stop = num_threshold_pixels_fulfilled & num_edge_pixels_fulfilled & close_to_crossing_edge_show;
	assign LEDR[10] = zebra_crossing_stop;
	
	assign pr_y_ready = 1'b1;

	// ========================================================================
	// Register values for display
	// ========================================================================
	
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels_show;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels_show;
	logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_components_show;
	logic [$clog2(IMG_HEIGHT)-1:0] edge_top_show;
	logic [$clog2(IMG_HEIGHT)-1:0] edge_bottom_show;
	logic [$clog2(IMG_WIDTH)-1:0] edge_left_show;
	logic [$clog2(IMG_WIDTH)-1:0] edge_right_show;
	logic [$clog2(IMG_HEIGHT)-1:0] threshold_bottom_show;
	logic close_to_crossing_edge_show;
	logic close_to_crossing_threshold_show;

	always_ff @(posedge clk_video or negedge rst_n) begin
		if (!rst_n) begin
			num_white_edge_pixels_show <= '0;
			num_white_threshold_pixels_show <= '0;
			num_connected_components_show <= '0;
			edge_top_show <= '0;
			edge_bottom_show <= '0;
			edge_left_show <= '0;
			edge_right_show <= '0;
			threshold_bottom_show <= '0;
			close_to_crossing_edge_show <= 1'b0;
			close_to_crossing_threshold_show <= 1'b0;
		end else begin
			if (white_count_valid) begin
				num_white_edge_pixels_show <= num_white_edge_pixels;
				num_white_threshold_pixels_show <= num_white_threshold_pixels;
				edge_top_show <= edge_top;
				edge_bottom_show <= edge_bottom;
				edge_left_show <= edge_left;
				edge_right_show <= edge_right;
				threshold_bottom_show <= threshold_bottom;
				close_to_crossing_edge_show <= close_to_crossing_edge;
				close_to_crossing_threshold_show <= close_to_crossing_threshold;
			end
			if (components_valid) begin
				num_connected_components_show <= num_connected_components;
			end
		end
	end

	// ========================================================================
	// 7-SEGMENT DISPLAY SELECTION
	// SW[1:0] selects display mode:
	//   00: Edge pixels (HEX3-0) and Threshold pixels (HEX7-4)
	//   01: Components (HEX3-0) and Edge Bottom Y (HEX7-4)
	//   10: Top edge Y (HEX3-0) and Bottom edge Y (HEX7-4)
	//   11: Threshold Bottom Y (HEX3-0) and Edge Bottom Y (HEX7-4)
	// ========================================================================
	
	logic [15:0] lower_display, upper_display;
	
	always_comb begin
		case (SW[1:0])
			2'b00: begin  // Default: edge and threshold counts
				lower_display = num_white_edge_pixels_show[15:0];
				upper_display = num_white_threshold_pixels_show[15:0];
			end
			2'b01: begin  // Components and edge bottom
				lower_display = num_connected_components_show[15:0];
				upper_display = {7'd0, edge_bottom_show[8:0]};
			end
			2'b10: begin  // Top and bottom edge Y
				lower_display = {7'd0, edge_top_show[8:0]};
				upper_display = {7'd0, edge_bottom_show[8:0]};
			end
			2'b11: begin  // Threshold bottom vs Edge bottom
				lower_display = {7'd0, threshold_bottom_show[8:0]};
				upper_display = {7'd0, edge_bottom_show[8:0]};
			end
		endcase
	end

	// ========================================================================
	// LED Display
	// ========================================================================
//	assign LEDG[0] = capturing;
//	assign LEDG[1] = valid_to_read;
//	assign LEDG[2] = SW[0];
//	assign LEDG[3] = components_valid;
//	assign LEDG[4] = (num_connected_components_show > 0);
//	assign LEDG[5] = (edge_bottom_show >= IMG_HEIGHT * 4 / 5);  // Bottom 20% (≥384)
//	assign LEDG[6] = close_to_crossing_edge_show;                    // Close to crossing (>380)
//	assign LEDG[7] = (num_white_edge_pixels_show > 2000);
	
	// // Show bounding box validity on LEDR[17:4]
	// assign LEDR[17] = (edge_bottom_show > edge_top_show);        // Valid vertical range
	// assign LEDR[16] = (edge_right_show > edge_left_show);        // Valid horizontal range
	// assign LEDR[15:14] = SW[1:0];                                // Show display mode
	// assign LEDR[13:10] = edge_bottom_show[8:5];                  // Upper bits of bottom Y
	// assign LEDR[9:6] = edge_top_show[8:5];                       // Upper bits of top Y
	// assign LEDR[5:4] = 2'b00;
	// LEDR[3:0] used by criteria flags
	
//	display u_display_lower (
//		.clk(clk_video),
//		.value(lower_display),
//		.display0(HEX0),
//		.display1(HEX1),
//		.display2(HEX2),
//		.display3(HEX3)
//	);
//
//	display u_display_upper (
//		.clk(clk_video),
//		.value(upper_display),
//		.display0(HEX4),
//		.display1(HEX5),
//		.display2(HEX6),
//		.display3(HEX7)
//	);

	// ========================================================================
	// VGA DISPLAY SELECTION
	// ========================================================================
	
	logic [7:0] pr_y_data_held;
	logic [7:0] pr_y_data_bw_held;
	
	always_ff @(posedge clk_video or negedge rst_n) begin
		if (!rst_n) begin
			pr_y_data_held <= '0;
			pr_y_data_bw_held <= '0;
		end else begin
			if (pr_y_valid) pr_y_data_held <= pr_y_data;
			if (pr_y_valid_bw) pr_y_data_bw_held <= pr_y_data_bw;
		end
	end
	
	wire [11:0] convolved_rgb444 = {pr_y_data_held[7:4], pr_y_data_held[7:4], pr_y_data_held[7:4]};
	wire [11:0] thresholded_rgb444 = {pr_y_data_bw_held[7:4], pr_y_data_bw_held[7:4], pr_y_data_bw_held[7:4]};
	
	wire use_convolved = ~KEY[1];
	wire [11:0] processed_pixel = use_convolved ? convolved_rgb444 : thresholded_rgb444;
	wire [11:0] colored_conv444 = {4'h0, pr_y_data_bw_held[7:4], 4'h0};
	wire [11:0] to_show = SW[0] ? processed_pixel : (SW[1] ? gray_px : (SW[2] : (zebra_crossing_stop ? coloured_conv444 : convolved_rgb444) ? video_data));

	vga_driver u_vga_driver (
		.clk(clk_video),
		.rst(~rst_n),
		.pixel(to_show),
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
