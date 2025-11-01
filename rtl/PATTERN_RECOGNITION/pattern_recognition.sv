module pattern_recognition #(
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
    
    // Optional: edge-detected image output
    output logic y_valid,
    input  logic y_ready,
    output logic [W-1:0] y_data
);

    localparam ADDR_WIDTH = $clog2(IMG_WIDTH*IMG_HEIGHT);

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
    // Step 2: Image BRAM (stores edge map)
    // ========================================================================
    logic [ADDR_WIDTH-1:0] bram_read_addr;
    logic [1:0]            bram_read_data;
    logic                  mark_visited_we;
    logic [ADDR_WIDTH-1:0] mark_visited_addr;

    binary_bram #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_image_bram (
        .clk(clk),
        .rst_n(rst_n),
        // Write stream from convolution
        .x_valid(y_valid),
        .x_ready(),
        .x_data(y_data),
        // Read port for detector
        .read_addr(bram_read_addr),
        .read_data(bram_read_data),
        // Mark visited (not used here but left for extension)
        .mark_visited_we(mark_visited_we),
        .mark_visited_addr(mark_visited_addr),
        // Control
        .capture_trigger(capture_trigger),
        .valid_to_read(valid_to_read),
        .capture_complete(),
        .capturing(capturing)
    );

    // ========================================================================
    // Step 3: Hough Transform (line detection)
    // ========================================================================
    logic hough_done;
    logic [15:0] num_lines;
    logic [15:0] line_theta [0:15];
    logic [15:0] line_rho   [0:15];

    hough_transform #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .THETA_STEPS(180),
        .RHO_BINS(1024),
        .ACC_WIDTH(8)
    ) u_hough_transform (
        .clk(clk),
        .rst_n(rst_n),
        .start(valid_to_read),
        .done(hough_done),
        // BRAM interface
        .bram_addr(bram_read_addr),
        .bram_data(bram_read_data),
        // Line output
        .num_lines(num_lines),
        .line_theta(line_theta),
        .line_rho(line_rho)
    );

    // ========================================================================
    // Step 4: Stripe Pattern Analyzer (detect zebra crossing)
    // ========================================================================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            detection_valid   <= 1'b0;
            crossing_detected <= 1'b0;
            stripe_count      <= 0;
        end else begin
            if (hough_done) begin
                detection_valid <= 1'b1;

                // Simplified placeholder logic:
                // If multiple near-parallel lines found, assert crossing.
                if (num_lines >= 3)
                    crossing_detected <= 1'b1;
                else
                    crossing_detected <= 1'b0;

                stripe_count <= num_lines[7:0];
            end else begin
                detection_valid <= 1'b0;
            end
        end
    end

endmodule
