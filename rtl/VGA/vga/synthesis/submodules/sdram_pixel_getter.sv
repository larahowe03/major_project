module sdram_pixel_getter #(
	parameter WIDTH      = 640,
	parameter HEIGHT     = 480,
	parameter PIXEL_BITS = 16, // RGB12
	parameter ADDR_WIDTH = 19

)(

	input logic clk,
	input logic reset,

	// Avalon-MM Interface - only reading from SDRAM as .mif file is already "written" in using Platform Designer
	input logic [PIXEL_BITS-1:0]	avm_readdata,
	input logic        	avm_readdatavalid,
	input logic        	avm_waitrequest,
	 
	output logic [ADDR_WIDTH-1:0]	avm_address,
	output logic			avm_read,
	
	// Pixel streaming connections to vga_streaming module
	input logic 			pixel_request,
	
	output logic [PIXEL_BITS-1:0] pixel_from_sdram, 
	output logic 			pixel_valid 	// asserts when there's a pixel ready to be sent

);

	// FSM states to determine when to read, wait and send pixels to vga_streaming module
	typedef enum logic [1:0] {
		IDLE,
		READ_REQ,
		WAIT_DATA	
	} pixelr_state;
	
	pixelr_state state, next_state;
	
	logic [ADDR_WIDTH-1:0] read_addr;
	logic [15:0] sdram_word;
	
	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			state <= IDLE;
		end
		else begin
			state <= next_state;
		end
	end

	
	// address counter from the .mif file
	always_ff @(posedge clk or posedge reset) begin
	
		if (reset) begin
			read_addr <= 0;
		end
		
		// increment the address counter by 2 bytes if there's a pixel ready to be sent
		// 2 bytes because of our 12-bit pixel size
		// AvalonMM read returns a 16-bit (2byte) value from SDRAM
		// we use the first 12 bits for our pixel and the other 4 are unused
		else if (pixel_valid && (read_addr < (WIDTH * HEIGHT * 2))) begin
			read_addr <= read_addr + 2;	
		end
	
	end
	
	
	// FSM logic 
	always_ff @(posedge clk or posedge reset) begin
	
		// reset everything
		if (reset) begin
			
			avm_read <= 0;
			avm_address <= 0;
			pixel_valid <= 0;
			pixel_from_sdram <= 0;
			next_state <= IDLE;
			
		end
		
		// pick what to do based on the state
		else begin
		
			pixel_valid <= 0;
			next_state <= IDLE;
		
			case(state) 
			
				IDLE : begin
				
					// waits until there's a pixel_request from vga_streaming module before changing state								
					if (pixel_request) begin
						next_state <= READ_REQ;
					end
					else begin
						next_state <= IDLE;
					end
				end
				
				
				READ_REQ : begin
				
					// waits for the SDRAM controller to be ready to issue a read
					if (!avm_waitrequest) begin
						avm_read <= 1;
						avm_address <= read_addr;
						next_state <= WAIT_DATA;
					end 
					
					// continue waiting for SDRAM to be ready
					else begin
						avm_read <= 0;
						next_state <= READ_REQ;
					end
				end
				
				
				WAIT_DATA : begin
					
					avm_read <= 0;
					
					// put the data from SDRAM into pixel_data to be sent to vga_streaming
					if (avm_readdatavalid) begin
						pixel_from_sdram <= {4'b0, avm_readdata[11:0]};
						pixel_valid <= 1;
						next_state <= IDLE;			
					end
					else begin
						next_state <= WAIT_DATA;
					end
				end
				
				
				default : begin
					avm_read <= 0;
					pixel_valid <= 0;
					next_state <= IDLE;
				end					
			
			
			endcase
		end
	end


endmodule
