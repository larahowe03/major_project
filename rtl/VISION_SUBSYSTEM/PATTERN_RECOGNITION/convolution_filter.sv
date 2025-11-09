module convolution_filter #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,          
    parameter W_FRAC = 0,
    parameter EDGE_THRESHOLD = 8'd150,
    parameter WHITE_THRESHOLD = 8'd150
)(
    input logic clk,
    input logic rst_n,
    
    // Input image data
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Outputs
    // convolution edge detection output
    output logic y_valid,
    output logic [W-1:0] y_data,

    // thresholded output
    output logic y_valid_bw,
    output logic [W-1:0] y_data_bw,

    // always ready
    input logic y_ready,

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
    
    // Add 20-pixel margin to ignore edges near borders as tehere are margins in the image seen on vga
    localparam MARGIN = 20;    
    logic convolution_valid;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            convolution_valid <= 1'b0;
        else if (handshake)
            convolution_valid <= (x_pos >= KERNEL_W - 1) && (y_pos >= KERNEL_H - 1) 
                              && (x_pos >= MARGIN) && (x_pos < IMG_WIDTH - MARGIN) 
                              && (y_pos >= MARGIN) && (y_pos < IMG_HEIGHT - MARGIN);
    end

    // Line buffers for convolution, must be image width by kernel height    
    logic [7:0] line_buffer [0:KERNEL_H-1][0:IMG_WIDTH-1];
    
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // technically could do '0, but this is more robust even if it is critical path
            line_buffer <= '{default:'0};
        end else begin
            if (handshake) begin
                for (int row = KERNEL_H - 1; row > 0; row--) begin
                    line_buffer[row][x_pos] <= line_buffer[row-1][x_pos];
                end
                line_buffer[0][x_pos] <= x_data;
            end
        end
    end
    
    // Window register for just holding the size of the kernel
    logic [W-1:0] window_reg [0:KERNEL_H-1][0:KERNEL_W-1];
        
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // technically could do '0, but this is more robust even if it is critical path
            window_reg <= '{default:'0};
        end else begin
            if (handshake) begin
                for (int row = 0; row < KERNEL_H; row++) begin
                    for (int col = KERNEL_W - 1; col > 0; col--) begin
                        window_reg[row][col] <= window_reg[row][col-1];
                    end
                    window_reg[row][0] <= line_buffer[row][x_pos];
                end
            end
        end
    end
    
    // Convolution on teh windowed region
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
    
    // Making sure it does not overflow
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
    
    // Binary thresholding so that it is either an edge or no edge
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
    logic [$clog2(IMG_WIDTH)-1:0] x_pos_d1;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos_d1;
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
            x_pos_d1 <= '0;
            y_pos_d1 <= '0;
            x_data_d1 <= '0;
            binary_result_d1 <= '0;
            last_pixel_d1 <= 1'b0;
        end else begin
            if (handshake) begin
                // Update delayed signals because there is a delay in this pipeline
                x_valid_d1 <= x_valid;
                convolution_valid_d1 <= convolution_valid;
                x_pos_d1 <= x_pos;
                y_pos_d1 <= y_pos;
                x_data_d1 <= x_data;
                binary_result_d1 <= binary_result;
                last_pixel_d1 <= last_pixel;
                
                // Edge detection output
                if (convolution_valid_d1) begin
                    y_data <= binary_result_d1;
                end else begin
                    y_data <= 8'd0;  // Black border where the margin is
                end
                
                // Threshold output
                if (x_data_d1 >= WHITE_THRESHOLD) begin
                    y_data_bw <= 8'd255;
                end else begin
                    y_data_bw <= 8'd0;
                end
                
                // Valid signals
                y_valid <= convolution_valid_d1;
                y_valid_bw <= x_valid_d1;
                
            end else if (y_ready) begin
                if (y_valid) begin
                    y_valid <= 1'b0;
                end
                if (y_valid_bw) begin
                    y_valid_bw <= 1'b0;
                end
            end
        end
    end

    // Counter for counding how many white thresholded pixels or how many convolution pixels
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            num_white_edge_pixels <= '0;
            num_white_threshold_pixels <= '0;
            white_count_valid <= 1'b0;
        end else begin
            if (handshake && last_pixel_d1) begin
                // valid pulse
                white_count_valid <= 1'b1;
            end else if (white_count_valid && handshake && x_pos > 10) begin
                // end ov valid pulse and also reset the counters for new frame
                white_count_valid <= 1'b0;  
                num_white_edge_pixels <= '0;
                num_white_threshold_pixels <= '0;
            end else begin
                // Count white edge pixels
                if (handshake && convolution_valid_d1 && binary_result_d1 == 8'd255) begin
                    num_white_edge_pixels <= num_white_edge_pixels + 1'b1;
                end
                
                // Count white threshold pixels
                if (handshake && x_valid_d1 && x_data_d1 >= WHITE_THRESHOLD) begin
                    num_white_threshold_pixels <= num_white_threshold_pixels + 1'b1;
                end
            end
        end
    end

endmodule