module convolution_filter #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,          
    parameter W_FRAC = 0,
    parameter EDGE_THRESHOLD = 8'd150,  // Changed from 150 (try 200 idk)
    parameter WHITE_THRESHOLD = 8'd120  // Changed from 150
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream
    output logic y_valid,          // Valid for edge detection
    output logic y_valid_bw,       // Valid for threshold (NEW - separate!)
    input logic y_ready,
    output logic [W-1:0] y_data,
    output logic [W-1:0] y_data_bw,
    
    // Kernel
    input logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1],

    // White pixel count
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels,
    output logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels,
    output logic white_count_valid
);

    // Position tracking
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    logic handshake;
    assign handshake = x_valid && x_ready;
    
    // Frame completion detection
    wire last_pixel = (x_pos == IMG_WIDTH - 1) && (y_pos == IMG_HEIGHT - 1);
        
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
        end else begin
            if (handshake) begin
                if (x_pos == IMG_WIDTH - 1) begin
                    x_pos <= '0;
                    if (y_pos == IMG_HEIGHT - 1) begin
                        y_pos <= '0;
                    end else begin
                        y_pos <= y_pos + 1;
                    end
                end else begin
                    x_pos <= x_pos + 1;
                end
            end
        end
    end
    
    wire convolution_valid_now = (x_pos >= KERNEL_W - 1) && (y_pos >= KERNEL_H - 1);
    logic convolution_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            convolution_valid <= 1'b0;
        else if (handshake)
            convolution_valid <= convolution_valid_now;
    end

    // Line buffers
    logic [W-1:0] line_buffer [0:KERNEL_H-1][0:IMG_WIDTH-1];
    
    integer init_row, init_col;
    initial begin
        for (init_row = 0; init_row < KERNEL_H; init_row = init_row + 1) begin
            for (init_col = 0; init_col < IMG_WIDTH; init_col = init_col + 1) begin
                line_buffer[init_row][init_col] = 8'h00;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (handshake) begin
            for (int row = KERNEL_H - 1; row > 0; row--) begin
                line_buffer[row][x_pos] <= line_buffer[row-1][x_pos];
            end
            line_buffer[0][x_pos] <= x_data;
        end
    end
    
    // Window register
    logic [W-1:0] window_reg [0:KERNEL_H-1][0:KERNEL_W-1];
    
    integer init_wrow, init_wcol;
    initial begin
        for (init_wrow = 0; init_wrow < KERNEL_H; init_wrow = init_wrow + 1) begin
            for (init_wcol = 0; init_wcol < KERNEL_W; init_wcol = init_wcol + 1) begin
                window_reg[init_wrow][init_wcol] = 8'h00;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (handshake) begin
            for (int row = 0; row < KERNEL_H; row++) begin
                for (int col = KERNEL_W - 1; col > 0; col--) begin
                    window_reg[row][col] <= window_reg[row][col-1];
                end
                window_reg[row][0] <= line_buffer[row][x_pos];
            end
        end
    end
    
    // Multiplication
    logic signed [2*W-1:0] mult_result [0:KERNEL_H-1][0:KERNEL_W-1];
    
    always_comb begin
        for (int row = 0; row < KERNEL_H; row++) begin
            for (int col = 0; col < KERNEL_W; col++) begin
                mult_result[row][col] = signed'(window_reg[row][col]) * signed'(kernel[row][col]);
            end
        end
    end
    
    // Accumulation
    localparam int NUM_TAPS = KERNEL_H * KERNEL_W;
    logic signed [$clog2(NUM_TAPS) + 2*W : 0] macc;
    
    always_comb begin
        macc = '0;
        for (int row = 0; row < KERNEL_H; row++) begin
            for (int col = 0; col < KERNEL_W; col++) begin
                macc = macc + mult_result[row][col];
            end
        end
    end
    
    // Truncation with clamping
    logic [W-1:0] truncated_result;
    
    always_comb begin
        if (macc[$clog2(NUM_TAPS) + 2*W]) begin
            truncated_result = 8'd0;
        end else if (macc > (255 << W_FRAC)) begin
            truncated_result = 8'd255;
        end else begin
            truncated_result = macc[W+W_FRAC-1:W_FRAC];
        end
    end
    
    // Binary thresholding
    logic [W-1:0] binary_result;
    
    always_comb begin
        if (truncated_result >= EDGE_THRESHOLD) begin
            binary_result = 8'd255;
        end else begin
            binary_result = 8'd0;
        end
    end
    
    // Output pipeline
    assign x_ready = y_ready | ~y_valid;

    logic x_valid_d1;
    logic convolution_valid_d1;
    logic [W-1:0] x_data_d1;
    logic [W-1:0] binary_result_d1;
    logic last_pixel_d1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_valid <= 1'b0;
            y_valid_bw <= 1'b0;
            y_data <= '0;
            y_data_bw <= '0;
            x_valid_d1 <= 1'b0;
            convolution_valid_d1 <= 1'b0;
            x_data_d1 <= '0;
            binary_result_d1 <= '0;
            last_pixel_d1 <= 1'b0;
        end else begin
            if (handshake) begin
                // Update delayed signals
                x_valid_d1 <= x_valid;
                convolution_valid_d1 <= convolution_valid;
                x_data_d1 <= x_data;
                binary_result_d1 <= binary_result;
                last_pixel_d1 <= last_pixel;
                
                // Edge detection output
                if (convolution_valid_d1) begin
                    y_data <= binary_result_d1;
                end else begin
                    y_data <= 8'd0;  // Black border
                end
                
                // Threshold output
                if (x_data_d1 >= WHITE_THRESHOLD) begin
                    y_data_bw <= 8'd255;
                end else begin
                    y_data_bw <= 8'd0;
                end
                
                // Valid signals - set OUTSIDE conditional logic
                y_valid <= convolution_valid_d1 && x_valid_d1;  // Only valid in conv region
                y_valid_bw <= x_valid_d1;  // Valid for all pixels
                
            end else if (y_ready) begin
                if (y_valid) y_valid <= 1'b0;
                if (y_valid_bw) y_valid_bw <= 1'b0;
            end
        end
    end

    // WHITE PIXEL COUNTER - IMPROVED
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_white_edge_pixels <= '0;
            num_white_threshold_pixels <= '0;
            white_count_valid <= 1'b0;
        end else begin
            // Signal frame complete and hold for multiple cycles
            if (handshake && last_pixel_d1) begin
                white_count_valid <= 1'b1;  // Start valid pulse
            end else if (white_count_valid && handshake && x_pos > 10) begin  // Hold for ~10 pixels
                white_count_valid <= 1'b0;  // End valid pulse
                // Reset counters AFTER valid pulse ends
                num_white_edge_pixels <= '0;
                num_white_threshold_pixels <= '0;
            end else begin
                // Count pixels during frame
                if (handshake && convolution_valid_d1 && binary_result_d1 == 8'd255) begin
                    num_white_edge_pixels <= num_white_edge_pixels + 1'b1;
                end
                
                if (handshake && x_valid_d1 && x_data_d1 >= WHITE_THRESHOLD) begin
                    num_white_threshold_pixels <= num_white_threshold_pixels + 1'b1;
                end
            end
        end
    end

endmodule