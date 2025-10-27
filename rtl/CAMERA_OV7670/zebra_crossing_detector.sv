module zebra_crossing_detector #(
    parameter IMG_WIDTH  = 320,
    parameter IMG_HEIGHT = 240,
    parameter W = 8
)(
    input  logic clk,
    input  logic rst_n,

    input  logic pixel_valid,
    input  logic [W-1:0] edge_pixel,

    output logic crossing_detected,
    output logic detection_valid,
    output logic [7:0] stripe_count
);

	// ========================================================================
	// TODO: FIX THE LOGIC IN HERE SO IT ACTUALLY DETECTS A CROSSING
	// ========================================================================

    // Tunable parameters
    localparam EDGE_THRESHOLD     = 8'd50;
    localparam MIN_EDGES_PER_ROW  = 60;
    localparam MIN_STRIPES        = 4;

    // Position tracking
    logic [$clog2(IMG_WIDTH)-1:0]  x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;

    // Per-row counters
    logic [15:0] edges_in_row;
    logic [7:0]  stripes_in_frame;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
            edges_in_row <= '0;
            stripes_in_frame <= '0;
            detection_valid <= 1'b0;
            crossing_detected <= 1'b0;
        end else if (pixel_valid) begin
            // Count pixels above threshold
            if (edge_pixel > EDGE_THRESHOLD)
                edges_in_row <= edges_in_row + 1'b1;

            // End of row?
            if (x_pos == IMG_WIDTH-1) begin
                // Row qualifies as a stripe?
                if (edges_in_row > MIN_EDGES_PER_ROW)
                    stripes_in_frame <= stripes_in_frame + 1'b1;

                edges_in_row <= '0;  // reset for next row
                x_pos <= '0;
                // Increment row
                if (y_pos == IMG_HEIGHT-1) begin
                    // End of frame → evaluate detection
                    crossing_detected <= (stripes_in_frame >= MIN_STRIPES);
                    detection_valid   <= 1'b1;
                    y_pos <= '0;
                    stripe_count <= stripes_in_frame;
                    stripes_in_frame <= '0;
                end else begin
                    y_pos <= y_pos + 1'b1;
                    detection_valid <= 1'b0;
                end
            end else begin
                x_pos <= x_pos + 1'b1;
                detection_valid <= 1'b0;
            end
        end else begin
            detection_valid <= 1'b0;
        end
    end

endmodule
