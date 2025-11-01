module pattern_recognition_lara #(
    parameter IMG_WIDTH  = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H   = 3,
    parameter KERNEL_W   = 3,
    parameter W          = 8,
    parameter W_FRAC     = 0
)(
    input  logic clk,
    input  logic rst_n,
    
    // Input pixel stream (from camera)
    input  logic x_valid,
    output logic x_ready,
    input  logic [W-1:0] x_data,

    // BRAM capture control
    input  logic capture_trigger,
    output logic valid_to_read,
    output logic capturing,

    // Edge detection kernel
    input  logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],
    
    // Detection outputs
    output logic crossing_detected,
    output logic detection_valid,
    output logic [7:0] stripe_count,
    
    // Edge-detected image output (for VGA display)
    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data,
    
    // Binary edge image output (from BRAM, for display/debug)
    output logic binary_valid,
    input  logic binary_ready,
    output logic [W-1:0] binary_data,

    // Additional outputs
    output logic [31:0] white_pixel_count,
    output logic [7:0] edge_group_count
);

    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;

    // ========================================================================
    // Step 1: Convolution filter (edge detection)
    // ========================================================================
    convolution_filter #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .KERNEL_H(KERNEL_H),
        .KERNEL_W(KERNEL_W),
        .W(W),
        .W_FRAC(W_FRAC)
    ) u_convolution_filter (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        .y_valid(y_valid),
        .y_ready(y_ready),
        .y_data(y_data),
        .kernel(kernel)
    );

    // ========================================================================
    // Step 2: Raw Image BRAM (grayscale)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] raw_addr;
    logic [1:0] raw_data;
    
    binary_bram #(
        .ADDR_WIDTH(TOTAL_PIXELS)
    ) u_raw_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(),
        .x_data(x_data),
        .read_addr(raw_addr),
        .read_data(raw_data),
        .mark_visited_we(1'b0),
        .mark_visited_addr('0),
        .capture_trigger(capture_trigger),
        .valid_to_read(),
        .capture_complete(),
        .capturing()
    );

    // ========================================================================
    // Step 3: Edge Image BRAM (2-bit: black/white/visited)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] edge_addr;
    logic [1:0] edge_data;
    logic mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;
    
    binary_bram #(
        .ADDR_WIDTH(TOTAL_PIXELS)
    ) u_edge_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(y_valid),
        .x_ready(),
        .x_data(y_data),
        .read_addr(edge_addr),
        .read_data(edge_data),
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr),
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(),
        .capturing(capturing)
    );

    // ========================================================================
    // Step 4: Binary Image Output Stream (from BRAM)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] binary_read_addr;
    logic binary_read_active;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binary_read_addr <= '0;
            binary_valid <= 1'b0;
            binary_read_active <= 1'b0;
        end else begin
            // Start reading when BRAM is valid and display is ready
            if (valid_to_read && !binary_read_active) begin
                binary_read_active <= 1'b1;
                binary_read_addr <= '0;
                binary_valid <= 1'b0;
            end
            
            // Stream out binary image
            if (binary_read_active) begin
                if (binary_ready || !binary_valid) begin
                    binary_valid <= 1'b1;
                    
                    if (binary_read_addr == TOTAL_PIXELS - 1) begin
                        binary_read_addr <= '0;
                        binary_read_active <= 1'b0;
                    end else begin
                        binary_read_addr <= binary_read_addr + 1;
                    end
                end
            end
        end
    end
    
    // Mux between edge detection read and binary output read
    logic [ADDR_WIDTH-1:0] final_edge_addr;
    logic [1:0] final_edge_data;
    
    assign final_edge_addr = binary_read_active ? binary_read_addr : edge_addr;
    
    // Read from BRAM
    always_ff @(posedge clk) begin
        final_edge_data <= edge_data;  // Latched edge data
    end
    
    // Convert 2-bit to 8-bit grayscale for display
    // 00 = black, 01 = white, 10 = visited (show as gray for debug)
    always_comb begin
        case (final_edge_data)
            2'b00: binary_data = 8'd0;    // Black
            2'b01: binary_data = 8'd255;  // White
            2'b10: binary_data = 8'd128;  // Gray (visited, for debug)
            default: binary_data = 8'd0;
        endcase
    end

    // ========================================================================
    // Step 5: Zebra Crossing Recognition
    // ========================================================================
    logic raw_is_white;
    assign raw_is_white = (raw_data[0] == 1'b1);
    
    logic edge_is_white;
    logic edge_is_visited;
    assign edge_is_white = (edge_data == 2'b01);
    assign edge_is_visited = (edge_data == 2'b10);
    
    logic visited_we;
    logic [ADDR_WIDTH-1:0] visited_addr;
    logic visited_wdata;
    logic visited_rdata;
    
    assign visited_addr = edge_addr;
    assign visited_rdata = edge_is_visited;
    assign mark_visited_we = visited_we;
    assign mark_visited_addr = visited_addr;
    
    zebra_crossing_recognition #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .WHITE_THRESHOLD(1),  // Binary check (0 or 1)
        .MIN_WHITE_PIXELS(50000),
        .MIN_EDGE_GROUPS(15),
        .MIN_GROUP_SIZE(20)
    ) u_zebra_recognition (
        .clk(clk),
        .rst_n(rst_n),
        .start_recognition(valid_to_read),
        .recognition_complete(detection_valid),
        .zebra_detected(crossing_detected),
        
        .raw_addr(raw_addr),
        .raw_data({7'b0, raw_is_white}),
        
        .edge_addr(edge_addr),
        .edge_data(edge_is_white),
        
        .visited_addr(visited_addr),
        .visited_we(visited_we),
        .visited_wdata(visited_wdata),
        .visited_rdata(visited_rdata),
        
        .white_pixel_count(white_pixel_count),
        .edge_group_count(edge_group_count)
    );
    
    assign stripe_count = edge_group_count;

endmodule