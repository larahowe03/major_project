module combined_bram #(
    parameter ADDR_WIDTH = 18  // for 640x480, 18 bits
)(
    input  logic clk,
    input  logic rst_n,

    // Input streams (from convolution/filter)
    input  logic x_valid_edge,
    output logic x_ready_edge,
    input  logic [7:0] x_data_edge,

    input  logic x_valid_bw,
    output logic x_ready_bw,
    input  logic [7:0] x_data_bw,

    // Read ports for detector
    input  logic [ADDR_WIDTH-1:0] edge_read_addr,
    output logic [1:0] edge_read_data,

    input  logic [ADDR_WIDTH-1:0] bw_read_addr,
    output logic [1:0] bw_read_data,

    // Write port for marking visited (edge only)
    input  logic mark_visited_we,
    input  logic [ADDR_WIDTH-1:0] mark_visited_addr,

    // Control signals
    input  logic capture_trigger,
    output logic valid_to_read,
    output logic capture_complete,
    output logic capturing
);

    typedef enum logic [1:0] {IDLE, CAPTURING, COMPLETE} state_t;
    state_t state;

    logic [ADDR_WIDTH-1:0] write_addr_edge;
    logic [ADDR_WIDTH-1:0] write_addr_bw;

    // 4-bit BRAM: [3:2]=edge pixel, [1:0]=BW pixel
    (* ramstyle = "M9K" *) logic [3:0] bram_array [0:2**ADDR_WIDTH-1];

    logic handshake_edge, handshake_bw;
    assign handshake_edge = x_valid_edge && x_ready_edge;
    assign handshake_bw   = x_valid_bw   && x_ready_bw;

    logic binary_edge, binary_bw;
    assign binary_edge = (x_data_edge == 8'd255);
    assign binary_bw   = (x_data_bw   == 8'd255);

    logic initial_reading;
    
    // ============================
    // State machine for capture
    // ============================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            write_addr_edge <= '0;
            write_addr_bw   <= '0;
            capture_complete <= 1'b0;
            capturing <= 1'b0;
            valid_to_read <= 1'b0;
            initial_reading <= 1'b1;
        end else begin
            capture_complete <= 1'b0;
            case (state)
                IDLE: begin
                    capturing <= 1'b0;
                    if (capture_trigger || initial_reading) begin
                        state <= CAPTURING;
                        capturing <= 1'b1;
                        write_addr_edge <= '0;
                        write_addr_bw   <= '0;
                        valid_to_read <= 1'b0;
                        initial_reading <= 1'b0;
                    end
                end

                CAPTURING: begin
                    // Write edge pixels
                    if (handshake_edge) begin
                        bram_array[write_addr_edge][3:2] <= binary_edge ? 2'b01 : 2'b00;
                        if (write_addr_edge == 2**ADDR_WIDTH - 1)
                            write_addr_edge <= '0;
                        else
                            write_addr_edge <= write_addr_edge + 1;
                    end

                    // Write BW pixels
                    if (handshake_bw) begin
                        bram_array[write_addr_bw][1:0] <= binary_bw ? 2'b01 : 2'b00;
                        if (write_addr_bw == 2**ADDR_WIDTH - 1)
                            write_addr_bw <= '0;
                        else
                            write_addr_bw <= write_addr_bw + 1;
                    end

                    // Check if capture is complete
                    if ((write_addr_edge == 2**ADDR_WIDTH-1 || !handshake_edge) &&
                        (write_addr_bw   == 2**ADDR_WIDTH-1 || !handshake_bw)) begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    capturing <= 1'b0;
                    capture_complete <= 1'b1;
                    valid_to_read <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign x_ready_edge = (state == CAPTURING);
    assign x_ready_bw   = (state == CAPTURING);

    // ============================
    // Dual-port read + mark visited
    // ============================
    always_ff @(posedge clk) begin
        // Mark visited affects edge bits only
        if (mark_visited_we && valid_to_read) begin
            bram_array[mark_visited_addr][3:2] <= 2'b10;
        end

        // Read ports
        edge_read_data <= bram_array[edge_read_addr][3:2];
        bw_read_data   <= bram_array[bw_read_addr][1:0];
    end

endmodule
