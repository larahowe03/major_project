module zebra_crossing_detector #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter MAX_EDGES = 2048,
    parameter MIN_WHITE_PIXELS = 15360,
    parameter MAX_WHITE_PIXELS = 53760,
    parameter MIN_EDGE_PIXELS = 1000,
    parameter MIN_CONNECTED_EDGE_PIXELS = 20,
    parameter MIN_CONNECTED_EDGE_INSTANCES = 10
)(
    input logic clk,
    input logic rst_n,

    input logic valid_to_read,

    // Edge list interface (sparse storage)
    output logic [$clog2(MAX_EDGES)-1:0] edge_read_idx,
    input logic [$clog2(IMG_WIDTH)-1:0] edge_x,
    input logic [$clog2(IMG_HEIGHT)-1:0] edge_y,
    input logic edge_valid,
    input logic [$clog2(MAX_EDGES)-1:0] num_edges,
    
    // Threshold image interface (keep for white pixel ratio check)
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] threshold_addr,
    input logic [1:0] threshold_data,

    // White pixel counts
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels,
    input logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels,
    input logic white_count_valid,

    // Outputs
    output logic num_threshold_pixels_fulfilled,
    output logic num_edge_pixels_fulfilled,
    output logic num_connected_edge_instances_fulfilled,
    
    output logic capture_trigger
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

    typedef enum logic [3:0] {
        IDLE,
        SCAN_EDGES,
        WAIT_EDGE_READ,
        CHECK_VISITED,
        START_COMPONENT,
        EXPLORE_NEIGHBORS,
        WAIT_NEIGHBOR_CHECK,
        PROCESS_NEIGHBOR,
        DONE
    } state_t;

    state_t state;

    logic signed [1:0] dx [0:7] = '{-1, 0, 1, -1, 1, -1, 0, 1};
    logic signed [1:0] dy [0:7] = '{-1, -1, -1, 0, 0, 1, 1, 1};

    logic signed [10:0] nx, ny;
    
    coord_t current_pixel;
    logic [$clog2(MAX_EDGES)-1:0] current_edge_idx;
    logic [$clog2(3)-1:0] neighbor_index;
    
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_edge_instances;
    logic [$clog2(MIN_CONNECTED_EDGE_PIXELS)-1:0] component_size;
    
    // Visited bitmap - much smaller, only for edges we're exploring
    // Use a small hash table or just mark in the edge list
    logic visited [0:MAX_EDGES-1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_edge_idx <= '0;
            num_connected_edge_instances <= '0;
            capture_trigger <= '0;
            edge_read_idx <= '0;
            
            // Clear visited array
            for (int i = 0; i < MAX_EDGES; i++) begin
                visited[i] <= 1'b0;
            end
        end else begin
            case(state)
                IDLE: begin
                    if (valid_to_read) begin
                        state <= SCAN_EDGES;
                        current_edge_idx <= '0;
                        capture_trigger <= '0;
                        num_connected_edge_instances <= '0;
                        
                        // Clear visited for new frame
                        for (int i = 0; i < MAX_EDGES; i++) begin
                            visited[i] <= 1'b0;
                        end
                    end
                end

                SCAN_EDGES: begin
                    if (current_edge_idx < num_edges) begin
                        edge_read_idx <= current_edge_idx;
                        state <= WAIT_EDGE_READ;
                    end else begin
                        state <= DONE;
                    end
                end
                
                WAIT_EDGE_READ: begin
                    state <= CHECK_VISITED;
                end
                
                CHECK_VISITED: begin
                    if (edge_valid && !visited[current_edge_idx]) begin
                        // Start new component from this edge
                        visited[current_edge_idx] <= 1'b1;
                        current_pixel <= '{x: edge_x, y: edge_y};
                        component_size <= 1;
                        neighbor_index <= '0;
                        state <= START_COMPONENT;
                    end else begin
                        // Already visited, move to next edge
                        current_edge_idx <= current_edge_idx + 1;
                        state <= SCAN_EDGES;
                    end
                end

                START_COMPONENT: begin
                    // Component started, now explore neighbors
                    if (component_size >= MIN_CONNECTED_EDGE_PIXELS) begin
                        // Large enough component!
                        num_connected_edge_instances <= num_connected_edge_instances + 1;
                        current_edge_idx <= current_edge_idx + 1;
                        state <= SCAN_EDGES;
                    end else begin
                        state <= EXPLORE_NEIGHBORS;
                    end
                end
                
                EXPLORE_NEIGHBORS: begin
                    if (neighbor_index < 8) begin
                        // Calculate neighbor position
                        nx = $signed({1'b0, current_pixel.x}) + dx[neighbor_index];
                        ny = $signed({1'b0, current_pixel.y}) + dy[neighbor_index];
                        
                        if (nx >= 0 && nx < IMG_WIDTH && ny >= 0 && ny < IMG_HEIGHT) begin
                            // Check if this neighbor is an edge pixel
                            // Need to search edge list for this coordinate
                            state <= WAIT_NEIGHBOR_CHECK;
                        end else begin
                            neighbor_index <= neighbor_index + 1;
                        end
                    end else begin
                        // No more neighbors, finalize component
                        if (component_size >= MIN_CONNECTED_EDGE_PIXELS) begin
                            num_connected_edge_instances <= num_connected_edge_instances + 1;
                        end
                        current_edge_idx <= current_edge_idx + 1;
                        state <= SCAN_EDGES;
                    end
                end
                
                WAIT_NEIGHBOR_CHECK: begin
                    // Simplified: just check a few nearby edges in list
                    // Full implementation would search edge_list for (nx, ny)
                    // For now, move to next neighbor
                    neighbor_index <= neighbor_index + 1;
                    state <= EXPLORE_NEIGHBORS;
                end

                DONE: begin
                    state <= IDLE;
                    capture_trigger <= 1'b1;
                end

            endcase
        end
    end
    
    // Threshold address for white pixel ratio checks
    assign threshold_addr = '0;  // Not used in sparse mode

endmodule