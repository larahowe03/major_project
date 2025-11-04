module sparse_edge_storage #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter MAX_EDGES = 2048  // Adjust based on expected edge density
)(
    input logic clk,
    input logic rst_n,
    
    // Write port (from edge detection stream)
    input logic write_valid,
    input logic [7:0] write_data,
    input logic [$clog2(IMG_WIDTH)-1:0] write_x,
    input logic [$clog2(IMG_HEIGHT)-1:0] write_y,
    
    // Capture control
    input logic capture_trigger,
    input logic frame_complete,  // Pulse when frame done
    output logic capturing,
    output logic valid_to_read,
    
    // Read port (for detector)
    input logic [$clog2(MAX_EDGES)-1:0] read_idx,
    output logic [$clog2(IMG_WIDTH)-1:0] edge_x,
    output logic [$clog2(IMG_HEIGHT)-1:0] edge_y,
    output logic edge_valid,
    
    // Statistics
    output logic [$clog2(MAX_EDGES)-1:0] num_edges,
    output logic buffer_overflow  // Warning if too many edges
);

    typedef struct packed {
        logic [$clog2(IMG_WIDTH)-1:0] x;
        logic [$clog2(IMG_HEIGHT)-1:0] y;
    } coord_t;
    
    // Sparse edge list - only 17 bits per edge (9 bits x + 8 bits y)
    // 2048 edges × 17 bits = 34,816 bits (vs 153,600 bits for full image!)
    (* ramstyle = "M9K" *) coord_t edge_list [0:MAX_EDGES-1];
    
    logic [$clog2(MAX_EDGES)-1:0] write_idx;
    logic [$clog2(MAX_EDGES)-1:0] num_edges_reg;
    
    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    state_t state;
    
    logic initial_capture;
    logic capture_trigger_d1;
    wire capture_trigger_edge = capture_trigger && !capture_trigger_d1;
    
    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_idx <= '0;
            num_edges_reg <= '0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
            buffer_overflow <= 1'b0;
            initial_capture <= 1'b1;
            capture_trigger_d1 <= 1'b0;
        end else begin
            capture_trigger_d1 <= capture_trigger;
            
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    
                    if (initial_capture || capture_trigger_edge) begin
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_idx <= '0;
                        valid_to_read <= 1'b0;
                        buffer_overflow <= 1'b0;
                        initial_capture <= 1'b0;
                    end
                end
                
                CAPTURING: begin
                    // Store edge pixel coordinates
                    if (write_valid && write_data == 8'd255) begin
                        if (write_idx < MAX_EDGES) begin
                            edge_list[write_idx] <= '{x: write_x, y: write_y};
                            write_idx <= write_idx + 1;
                        end else begin
                            buffer_overflow <= 1'b1;  // Too many edges!
                        end
                    end
                    
                    // Wait for frame to complete
                    if (frame_complete) begin
                        num_edges_reg <= write_idx;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    capturing <= 1'b0;
                    valid_to_read <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Read port - lookup edge coordinates by index
    always_ff @(posedge clk) begin
        if (read_idx < num_edges_reg) begin
            edge_x <= edge_list[read_idx].x;
            edge_y <= edge_list[read_idx].y;
            edge_valid <= 1'b1;
        end else begin
            edge_x <= '0;
            edge_y <= '0;
            edge_valid <= 1'b0;
        end
    end
    
    assign num_edges = num_edges_reg;

endmodule