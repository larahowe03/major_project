module vga_streaming #(
	parameter WIDTH  = 320,
   parameter HEIGHT = 240,
   parameter PIXEL_BITS = 8 // GRAYSCALE = 8, RGB = 12
)(
   input logic 			clk,
   input logic				reset,
   input logic [8:0]		BPM_estimate,
	input logic 			beat_pulse,
	

   // Avalon-ST Interface
   output logic [29:0] data,
   output logic        startofpacket,
   output logic        endofpacket,
   output logic        valid,
   input  logic        ready
);

   //------------- reading in the image -------------

   localparam NumPixels = WIDTH * HEIGHT;

   // Single grayscale image in BRAM (preloaded)
   (* ram_init_file = "barrytennis_grayscale.mif" *) reg [PIXEL_BITS-1:0] image [0:NumPixels-1];
	 
	 // just for simulation
//	`ifndef SYNTHESIS
//   initial begin
//       $readmemh("rainbow_100x100.hex", image);  // or .mem if you convert
//   end
//   `endif
	
	// Pixel counter
   logic [$clog2(NumPixels)-1:0] pixel_index = 0, pixel_index_next;

   // Register to hold current pixel
   logic [PIXEL_BITS-1:0] pixel_q;
   logic read_enable;
	logic [PIXEL_BITS-1:0] filtered_pixel;
	
	 // Get the next pixel
   always_ff @(posedge clk) begin : pixel_getter
       if (read_enable) begin
           pixel_q <= image[pixel_index_next];
       end
   end
	
	// valid should be set to low when we are in reset - otherwise, we are 
	// constantly streaming data (valid stays high)
	assign valid = ~reset; 

	assign pixel_index_next = (pixel_index == NumPixels-1) ? 0 : pixel_index+1;
	
	// this is to ensure that convolution filter runs
	assign advance = valid & ready;
   
	// this bit of logic basically goes through the image indexes
	always_ff @(posedge clk) begin : img_pixel_advance
       // set pixel_index based on handshaking protocol. Remember the reset!!
       if (reset) begin
           pixel_index <= 0;
       end
       else if (valid && ready) begin
           pixel_index <= pixel_index_next;
       end
   end
	 
	 
	//------------- instantiate fake signal generator module -------------
	 
	logic [8:0] BPM;
	logic       beat;

	 
	audio_signal_generator signal_gen (
		.clk(clk),
		.reset(reset),
		.switches(BPM_estimate[8:0]),
		.button(beat_pulse),
		.BPM(BPM),
		.beat(beat)	 
	 );
	 

	 
	//------------- instantiate filter selector module -------------
	 
	image_filter_selector #(
		.WIDTH(WIDTH),
		.HEIGHT(HEIGHT),
		.PIXEL_BITS(PIXEL_BITS)	
	 ) filter_sel (
		.clk(clk),
		.reset(reset),
		.BPM_estimate(BPM),
		.advance(advance),
		.beat_pulse(beat),
		.pixel_in(pixel_q),
		.pixel_out(filtered_pixel)
	 );
	 
	 
	 
   //------------- streaming to vga section -------------

   // Toggle the read_enable flag either on reset or a handshake
	always_comb begin
		read_enable = reset | (valid & ready);
	end


   assign startofpacket = pixel_index == 0;         // Start of frame
   assign endofpacket = pixel_index == NumPixels-1; // End of frame


	// =========== DATA OUTPUT FOR GRAYSCALE SPECIFICALLY ===========
	
	assign data = {
				{filtered_pixel, 2'b00},  // Red
				{filtered_pixel, 2'b00},  // Green
				{filtered_pixel, 2'b00}   // Blue
	};
	
	


endmodule
