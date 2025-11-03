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
    output logic capture_trigger,

    // visited map interface
    output logic mark_visited_we,
    output logic [ADDR_WIDTH-1:0] mark_visited_addr,
    output logic [1:0] mark_visited_data
);

    // Criteria 1: need enough white regions
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) num_threshold_pixels_fulfilled <= 1'b0;
        else if (white_count_valid) begin
            num_threshold_pixels_fulfilled <= (num_white_threshold_pixels > MIN_WHITE_PIXELS &&
                                              num_white_threshold_pixels < MAX_WHITE_PIXELS);
        end
    end

    // Criteria 2: need enough edge pixels
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) num_edge_pixels_fulfilled <= 1'b0;
        else if (white_count_valid) begin
            num_edge_pixels_fulfilled <= (num_white_edge_pixels > MIN_EDGE_PIXELS);
        end
    end

    // Criteria 3: need enough connected components
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) num_connected_edge_instances_fulfilled <= 1'b0;
        else if (state == IDLE || state == DONE) begin
            num_connected_edge_instances_fulfilled <= (num_connected_edge_instances >= MIN_CONNECTED_EDGE_INSTANCES);
        end
    end

    typedef struct packed {
        logic [$clog2(IMG_WIDTH)-1:0] x;
        logic [$clog2(IMG_HEIGHT)-1:0] y;
    } coord_t;

    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;

    typedef enum logic [3:0] {
        IDLE,
        READING,
        PROCESSING,
        WAIT_NEIGHBOR,
        WAIT_EDGE_READ,
        PROCESS_NEIGHBOR,
        DONE
    } state_t;

    state_t state;

    logic signed [1:0] dx [0:7] = '{-1,0,1,-1,1,-1,0,1};
    logic signed [1:0] dy [0:7] = '{-1,-1,-1,0,0,1,1,1};

    logic signed [10:0] nx;
    logic signed [10:0] ny;

    // Temporary registers for neighbor read
    coord_t current_pixel;
    coord_t neighbor_pixel;
    logic [ADDR_WIDTH-1:0] neighbor_addr;
    logic [$clog2(3)-1:0] neighbor_index; // 0..7 for 8 neighbors

    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_edge_instances;
	 
	 logic [$clog2(MIN_CONNECTED_EDGE_PIXELS)-1:0] component_size;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= 0;
            y_pos <= 0;
            state <= IDLE;
            num_connected_edge_instances <= 0;
            mark_visited_we <= 0;
            capture_trigger <= 0;
        end else begin
            case(state)
                IDLE: begin
                    if (valid_to_read) begin
                        state <= READING;
                        x_pos <= 0;
                        y_pos <= 0;
                        capture_trigger <= 0;
                        num_connected_edge_instances <= 0;
                    end
                end

                READING: begin
                    state <= PROCESSING; // BRAM read latency
                end

                PROCESSING: begin
                    // Start exploration if white edge and not visited
                    if (edge_data == 2'b01) begin
                        current_pixel <= '{x_pos, y_pos};
                        component_size <= 1;
                        neighbor_index <= 0;
                        mark_visited_we <= 1'b1;
                        mark_visited_addr <= y_pos*IMG_WIDTH + x_pos;
                        mark_visited_data <= 2'b10; // mark visited
                        state <= WAIT_NEIGHBOR;
                    end else begin
                        // Move to next pixel
                        if (x_pos < IMG_WIDTH-1) x_pos <= x_pos + 1;
                        else begin
                            x_pos <= 0;
                            if (y_pos < IMG_HEIGHT-1) y_pos <= y_pos + 1;
                            else state <= DONE;
                        end
                    end
                end

                WAIT_NEIGHBOR: begin
                    if (neighbor_index < 8 && component_size < MIN_CONNECTED_EDGE_PIXELS) begin
                        nx = $signed(current_pixel.x) + dx[neighbor_index];
                        ny = $signed(current_pixel.y) + dy[neighbor_index];

                        if (nx >= 0 && nx < IMG_WIDTH && ny >= 0 && ny < IMG_HEIGHT) begin
                            neighbor_addr <= ny*IMG_WIDTH + nx;
                            neighbor_pixel <= '{nx[$clog2(IMG_WIDTH)-1:0], ny[$clog2(IMG_HEIGHT)-1:0]};
                            mark_visited_we <= 1'b0; // don't mark yet
                            state <= WAIT_EDGE_READ;
                        end else begin
                            neighbor_index <= neighbor_index + 1;
                        end
                    end else begin
                        // either done with neighbors or hit 20 pixels
                        if (component_size >= MIN_CONNECTED_EDGE_PIXELS)
                            num_connected_edge_instances <= num_connected_edge_instances + 1;
                        state <= PROCESSING;
                    end
                end

                WAIT_EDGE_READ: begin
                    // BRAM read latency
                    state <= PROCESS_NEIGHBOR;
                end

                PROCESS_NEIGHBOR: begin
                    if (edge_data == 2'b01 && component_size < MIN_CONNECTED_EDGE_PIXELS) begin
                        mark_visited_we <= 1'b1;
                        mark_visited_addr <= neighbor_addr;
                        mark_visited_data <= 2'b10; // mark visited

                        // move to this neighbor as next current_pixel
                        current_pixel <= neighbor_pixel;
                        component_size <= component_size + 1;
                        neighbor_index <= 0; // restart neighbors from this new pixel
                        state <= WAIT_NEIGHBOR;
                    end else begin
                        neighbor_index <= neighbor_index + 1;
                        state <= WAIT_NEIGHBOR;
                    end
                end





                DONE: begin
                    state <= IDLE;
                    capture_trigger <= 1;
                end

            endcase
        end
    end

    assign edge_addr = (state == WAIT_EDGE_READ || state == PROCESS_NEIGHBOR) ? neighbor_addr : y_pos*IMG_WIDTH + x_pos;
    assign bw_addr   = y_pos*IMG_WIDTH + x_pos;

endmodule