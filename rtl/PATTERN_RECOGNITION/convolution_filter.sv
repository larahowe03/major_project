module convolution_filter #(
    parameter IMG_WIDTH = 320,
    parameter IMG_HEIGHT = 240,
    parameter KERNEL_H = 3,
    parameter KERNEL_W = 3,
    parameter W = 8,          
    parameter W_FRAC = 0    
)(
    input logic clk,
    input logic rst_n,
    
    // Input stream (ready-valid handshake)
    input logic x_valid,
    output logic x_ready,
    input logic [W-1:0] x_data,
    
    // Output stream (ready-valid handshake)
    output logic y_valid,
    input logic y_ready,
    output logic [W-1:0] y_data,
    
    // Impulse response
    input logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1]
);

    // ========================================================================
    // 1. POSITION TRACKING (X, Y coordinates in the image)
    // ========================================================================
    
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;

    logic handshake;
    assign handshake = x_valid && x_ready;
        
    // Scan across each row down the image
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
    
    // We can output valid convolution results after buffering enough rows/cols
    // Need (KERNEL_H-1) rows buffered and (KERNEL_W-1) columns processed
    wire convolution_valid_now = (x_pos >= KERNEL_W - 1) && (y_pos >= KERNEL_H - 1);

    logic convolution_valid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            convolution_valid <= 1'b0;
        else if (handshake)
            convolution_valid <= convolution_valid_now;
    end

    
    // ========================================================================
    // 2. LINE BUFFERS (Store previous rows for 2D windowing)
    // ========================================================================
    
    logic [W-1:0] line_buffer [0:KERNEL_H-1][0:IMG_WIDTH-1];
    
    // Initialize line buffer to prevent xxx values
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
            // Shift rows: line[i] <- line[i-1], line[0] <- new data
            for (int row = KERNEL_H - 1; row > 0; row--) begin
                line_buffer[row][x_pos] <= line_buffer[row-1][x_pos];
            end
            line_buffer[0][x_pos] <= x_data;
        end
    end
    
    // ========================================================================
    // 3. 2D SHIFT REGISTER (KERNEL_H x KERNEL_W sliding window)
    // ========================================================================
    
    logic [W-1:0] window_reg [0:KERNEL_H-1][0:KERNEL_W-1];
    
    // Initialize window register to prevent xxx values
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
                // Shift horizontally within each row
                for (int col = KERNEL_W - 1; col > 0; col--) begin
                    window_reg[row][col] <= window_reg[row][col-1];
                end
                // Load new column from line buffers
                window_reg[row][0] <= line_buffer[row][x_pos];
            end
        end
    end
    
    // ========================================================================
    // 4. MULTIPLY EACH WINDOW ELEMENT BY KERNEL COEFFICIENT
    // ========================================================================
    
    logic signed [2*W-1:0] mult_result [0:KERNEL_H-1][0:KERNEL_W-1];
    
    always_comb begin
        for (int row = 0; row < KERNEL_H; row++) begin
            for (int col = 0; col < KERNEL_W; col++) begin
                mult_result[row][col] = signed'(window_reg[row][col]) * signed'(kernel[row][col]);
            end
        end
    end
    
    // ========================================================================
    // 5. MULTIPLY-ACCUMULATE (MAC): Sum all multiplication results
    // ========================================================================
    
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
    
    // ========================================================================
    // 6. FIXED-POINT TRUNCATION (Extract properly scaled result)
    // ========================================================================
    
    // Truncate macc to extract the W-bit result at the correct fixed-point position
    // For W_FRAC=0 (integer): extract bits [W-1:0]
    // For W_FRAC>0 (fixed-point): extract bits [W+W_FRAC-1:W_FRAC]
    wire [W-1:0] truncated_result = macc[W+W_FRAC-1:W_FRAC];
    
    // ========================================================================
    // 7. OUTPUT REGISTER (Pipeline and handshake control)
    // ========================================================================
    
    // Backpressure: we're ready if downstream is ready or our output register is empty
    assign x_ready = y_ready | ~y_valid;
    
    // Delay valid by 1 cycle to account for pipeline
    logic x_valid_d1;
    logic convolution_valid_d1;
    logic [W-1:0] x_data_d1;  // Also delay the input data for border passthrough
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_valid <= 1'b0;
            y_data <= '0;
            x_valid_d1 <= 1'b0;
            convolution_valid_d1 <= 1'b0;
            x_data_d1 <= '0;
        end else begin
            // Update pipeline when handshake occurs
            if (handshake) begin
                x_valid_d1 <= x_valid;
                convolution_valid_d1 <= convolution_valid;
                x_data_d1 <= x_data;  // Delay input data
                
                // Output convolution result (with proper fixed-point truncation)
                // Use DELAYED convolution_valid to match the y_valid timing
                if (convolution_valid_d1) begin
                    y_data <= truncated_result;  // Extract properly scaled bits
                end else begin
                    // Border handling: pass through delayed input pixel
                    y_data <= x_data_d1;
                end
                
                // Set valid after 1 cycle delay (for ALL pixels, not just convolved ones)
                y_valid <= x_valid_d1;  // Output valid whenever input was valid
            end else if (y_ready && y_valid) begin
                // Clear valid when downstream consumes data (only if no new data)
                y_valid <= 1'b0;
            end
        end
    end

endmodule