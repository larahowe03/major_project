module zebra_crossing_detector #(
    parameter IMG_WIDTH  = 640,
    parameter IMG_HEIGHT = 480,
    parameter ADDR_WIDTH,
    parameter MIN_WHITE_PIXELS = 61440,    // 20% of 307200 pixels
    parameter MAX_WHITE_PIXELS = 208320,   // 70% of 307200 pixels
    parameter MIN_EDGE_PIXELS = 2000,   // guesstimate
    parameter MIN_CONNECTED_EDGE_PIXELS = 20,
    parameter MIN_CONNECTED_EDGE_INSTANCES = 10
)(
    input logic clk,
    input logic rst_n,

    input logic valid_to_read,  // Allowed to read from BRAM

    // Edge image BRAM interface
    output logic [ADDR_WIDTH-1:0] edge_addr,
    input logic [1:0] edge_data,

    // BW thresholded image BRAM interface
    output logic [ADDR_WIDTH-1:0] bw_addr,
    input logic [1:0] bw_data,

    // White pixel counts
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels,
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels,
    input logic white_count_valid,

    // Outputs for debugging
    output logic num_threshold_pixels_fulfilled,
    output logic num_edge_pixels_fulfilled,
    output logic num_connected_edge_instances_fulfilled,

    // output for reading a new frame to bram
    output logic capture_trigger
);

    // ***Condition 1: number of white pixels within allowable range
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_threshold_pixels_fulfilled <= 1'b0;
        end else begin
            // Update when white count is valid
            if (white_count_valid) begin
                if (num_white_threshold_pixels > MIN_WHITE_PIXELS && 
                    num_white_threshold_pixels < MAX_WHITE_PIXELS) begin
                    num_threshold_pixels_fulfilled <= 1'b1;
                end else begin
                    num_threshold_pixels_fulfilled <= 1'b0;
                end
            end
        end
    end

    // ***Condition 2: number of edge pixels within allowable range

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_edge_pixels_fulfilled <= 1'b0;
        end else begin
            // Update when white count is valid
            if (white_count_valid) begin
                if (num_edge_pixels_fulfilled > MIN_EDGE_PIXELS) begin
                    num_edge_pixels_fulfilled <= 1'b1;
                end else begin
                    num_edge_pixels_fulfilled <= 1'b0;
                end
            end
        end
    end

    // ***Condition 3: 10 instances of 20 connected pixels
    
    logic following_edge; // keeps track of whether an edge has been found and if it is tracking it, essentially a state machine
    
    // variables for position tracking
    logic [$clog2(IMG_WIDTH)-1:0] x_pos, x_pos_tracking;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos, y_pos_tracking;

    // Add state machine
    typedef enum logic [1:0] {
        IDLE,
        READING,
        PROCESSING,
        DONE
    } state_t;

    state_t state;

    // Position tracking with BRAM read control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
            state <= IDLE;
            num_connected_edge_instances_fulfilled <= '0;
            following_edge <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if (valid_to_read) begin  // Wait for BRAM to be ready
                        state <= READING;
                        x_pos <= '0;
                        y_pos <= '0;
                        capture_trigger <= '0;
                    end
                end
                
                READING: begin
                    // Wait for BRAM read latency (usually 1-2 cycles)
                    state <= PROCESSING;
                end
                
                PROCESSING: begin
                    // Process current pixel (edge_data and bw_data are now valid)
                    
                    // TODO: Add your edge detection logic here
                    
                    // Move to next pixel
                    if (x_pos < IMG_WIDTH - 1) begin
                        x_pos <= x_pos + 1'b1;
                        state <= READING;  // Need to read next pixel
                    end else begin
                        x_pos <= '0;
                        if (y_pos < IMG_HEIGHT - 1) begin
                            y_pos <= y_pos + 1'b1;
                            state <= READING;
                        end else begin
                            y_pos <= '0;
                            state <= DONE;  // Finished scanning frame
                        end
                    end
                end
                
                DONE: begin
                    // Processing complete, wait for next capture
                    if (!valid_to_read) begin
                        state <= IDLE;
                        capture_trigger <= '1;
                    end
                end
            endcase
        end
    end

    // Drive BRAM address
    assign edge_addr = y_pos * IMG_WIDTH + x_pos;
    assign bw_addr = y_pos * IMG_WIDTH + x_pos;

endmodule