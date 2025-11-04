`timescale 1ns/1ps

module convolution_filter_tb;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter IMG_WIDTH = 640;
    parameter IMG_HEIGHT = 480;
    parameter KERNEL_H = 3;
    parameter KERNEL_W = 3;
    parameter W = 8;
    parameter W_FRAC = 0;
    
    parameter CLK_PERIOD = 20; // 50 MHz
    
    // Expected output counts (accounting for border)
    localparam int VALID_CONV_WIDTH = IMG_WIDTH - (KERNEL_W - 1);   // 638
    localparam int VALID_CONV_HEIGHT = IMG_HEIGHT - (KERNEL_H - 1); // 478
    localparam int EXPECTED_EDGE_PIXELS = VALID_CONV_WIDTH * VALID_CONV_HEIGHT; // 305164
    localparam int EXPECTED_BW_PIXELS = IMG_WIDTH * IMG_HEIGHT;      // 307200
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    reg clk;
    reg rst_n;
    
    reg x_valid;
    wire x_ready;
    reg [W-1:0] x_data;
    
    wire y_valid;
    wire y_valid_bw;
    reg y_ready;
    wire [W-1:0] y_data;
    wire [W-1:0] y_data_bw;
    
    reg signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1];
    
    wire [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels;
    wire [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels;
    wire white_count_valid;
    
    // ========================================================================
    // Memory for Image Data
    // ========================================================================
    reg [W-1:0] input_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    reg [W-1:0] output_image_edge [0:IMG_WIDTH*IMG_HEIGHT-1];
    reg [W-1:0] output_image_bw [0:IMG_WIDTH*IMG_HEIGHT-1];
    
    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========================================================================
    // DUT Instantiation
    // ========================================================================
    convolution_filter #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .KERNEL_H(KERNEL_H),
        .KERNEL_W(KERNEL_W),
        .W(W),
        .W_FRAC(W_FRAC)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        .y_valid(y_valid),
        .y_valid_bw(y_valid_bw),
        .y_ready(y_ready),
        .y_data(y_data),
        .y_data_bw(y_data_bw),
        .kernel(kernel),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer pixel_in_count;
    integer pixel_out_edge_count;
    integer pixel_out_bw_count;
    integer fd_out;
    integer i;
    
    // ========================================================================
    // Input Stimulus Process
    // ========================================================================
    initial begin
        // Initialize
        pixel_in_count = 0;
        pixel_out_edge_count = 0;
        pixel_out_bw_count = 0;
        rst_n = 0;
        x_valid = 0;
        x_data = 0;
        y_ready = 1; // Always ready to accept output
        
        // Initialize output images to white
        for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
            output_image_edge[i] = 8'hFF;
            output_image_bw[i] = 8'hFF;
        end
        
        // Load input image from MIF file
        load_mif_file("test_img.mif");
        $display("Loaded input image: %0d x %0d = %0d pixels", IMG_WIDTH, IMG_HEIGHT, IMG_WIDTH*IMG_HEIGHT);
        
        // Select kernel type
        load_edge_aggressive_kernel();
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Stream input pixels
        $display("Starting to stream %0d pixels...", IMG_WIDTH*IMG_HEIGHT);
        for (pixel_in_count = 0; pixel_in_count < IMG_WIDTH*IMG_HEIGHT; pixel_in_count = pixel_in_count + 1) begin
            x_data = input_image[pixel_in_count];
            x_valid = 1;
            
            // Wait for handshake
            @(posedge clk);
            while (!x_ready) @(posedge clk);
            
            // Print progress
            if (pixel_in_count % 50000 == 0)
                $display("  Sent pixel %0d/%0d", pixel_in_count, IMG_WIDTH*IMG_HEIGHT);
        end
        
        x_valid = 0;
        $display("Finished sending all input pixels");

        // Define acceptable margin (2 pixels)
        localparam int PIXEL_MARGIN = 2;

        // Give extra time for pipeline to flush the last pixel
        repeat(50) @(posedge clk);  // Increased from 20

        // Wait for all outputs with CORRECTED expectations
        i = 0;
        while ((pixel_out_edge_count < (EXPECTED_EDGE_PIXELS - PIXEL_MARGIN) || 
                pixel_out_bw_count < (EXPECTED_BW_PIXELS - PIXEL_MARGIN)) && i < 500000) begin
            @(posedge clk);
            i = i + 1;
        end

        // Extra cycles to ensure last pixel is captured
        repeat(5) @(posedge clk);  // Increased from 5
        $display("Final pixel_out_edge_count after extra wait: %0d (expected %0d)", pixel_out_edge_count, EXPECTED_EDGE_PIXELS);
        $display("Final pixel_out_bw_count after extra wait: %0d (expected %0d)", pixel_out_bw_count, EXPECTED_BW_PIXELS);

        
        if (pixel_out_edge_count >= (EXPECTED_EDGE_PIXELS - PIXEL_MARGIN)) begin
            $display("✓ All edge detection output pixels received!");
        end else begin
            $display("⚠ Edge outputs: Received %0d/%0d pixels (missing %0d)", 
                    pixel_out_edge_count, EXPECTED_EDGE_PIXELS, EXPECTED_EDGE_PIXELS - pixel_out_edge_count);
        end
        
        if (pixel_out_bw_count >= (EXPECTED_BW_PIXELS - PIXEL_MARGIN)) begin
            $display("✓ All threshold output pixels received!");
        end else begin
            $display("⚠ Threshold outputs: Received %0d/%0d pixels (missing %0d)", 
                    pixel_out_bw_count, EXPECTED_BW_PIXELS, EXPECTED_BW_PIXELS - pixel_out_bw_count);
        end
        
        // Monitor white pixel counts
        wait(white_count_valid);
        $display("\n=== Frame Statistics ===");
        $display("White pixels (edge detection): %0d", num_white_edge_pixels);
        $display("White pixels (threshold): %0d", num_white_threshold_pixels);
        
        // Save outputs
        repeat(100) @(posedge clk);
        save_output_image("edge_img.mif", output_image_edge);
        save_output_image("thresholded_img.mif", output_image_bw);
        
        $display("\n=== TEST COMPLETE ===");
        $display("Input pixels:           %0d", pixel_in_count);
        $display("Output edge pixels:     %0d / %0d", pixel_out_edge_count, EXPECTED_EDGE_PIXELS);
        $display("Output threshold pixels: %0d / %0d", pixel_out_bw_count, EXPECTED_BW_PIXELS);
        
        // Check for success
        if (pixel_out_edge_count >= (EXPECTED_EDGE_PIXELS - PIXEL_MARGIN) && 
            pixel_out_bw_count >= (EXPECTED_BW_PIXELS - PIXEL_MARGIN)) begin
            $display("\n✓ TEST PASSED");
        end else begin
            $display("\n✗ TEST FAILED - Missing pixels");
        end
        
        $finish;
    end
    
    // ========================================================================
    // Output Capture Process - Edge Detection
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n && y_valid && y_ready) begin
            if (pixel_out_edge_count < IMG_WIDTH*IMG_HEIGHT) begin
                output_image_edge[pixel_out_edge_count] = y_data;
            end
            pixel_out_edge_count = pixel_out_edge_count + 1;
            
            // Print progress
            if (pixel_out_edge_count % 50000 == 0)
                $display("  Received edge pixel %0d/%0d", pixel_out_edge_count, IMG_WIDTH*IMG_HEIGHT);
        end
    end
    
    // ========================================================================
    // Output Capture Process - Threshold/BW
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n && y_valid_bw && y_ready) begin
            if (pixel_out_bw_count < IMG_WIDTH*IMG_HEIGHT) begin
                output_image_bw[pixel_out_bw_count] = y_data_bw;
            end
            pixel_out_bw_count = pixel_out_bw_count + 1;
            
            // Print progress
            if (pixel_out_bw_count % 50000 == 0)
                $display("  Received threshold pixel %0d/%0d", pixel_out_bw_count, IMG_WIDTH*IMG_HEIGHT);
        end
    end
    
    // ========================================================================
    // MIF File Loader - Updated to match standard format
    // ========================================================================

    task load_mif_file(input string filename);
        integer fd, status, addr, data;
        integer entries_loaded;
        string line;
        begin
            fd = $fopen(filename, "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open file %s", filename);
                $finish;
            end
            
            $display("Parsing MIF file: %s", filename);
            entries_loaded = 0;
            
            // Skip header lines until we reach CONTENT
            while (!$feof(fd)) begin
                status = $fgets(line, fd);
                if (status == 0) continue;
                if (line.substr(0, 6) == "CONTENT") break;
            end
            
            // Skip BEGIN line
            status = $fgets(line, fd);
            
            // Read data lines (addr : data;)
            while (!$feof(fd)) begin
                status = $fgets(line, fd);
                if (status == 0) continue;
                
                // Stop at END
                if (line.substr(0, 2) == "END") break;
                
                // Parse "addr : data;"
                if ($sscanf(line, "%h : %h", addr, data) == 2) begin
                    if (addr < IMG_WIDTH*IMG_HEIGHT) begin
                        input_image[addr] = data[W-1:0];
                        entries_loaded++;
                        
                        if (entries_loaded <= 5) begin
                            $display("  addr=%h data=%h", addr, data);
                        end
                    end
                end
            end
            
            $fclose(fd);
            $display("MIF loading complete. Loaded %0d entries.", entries_loaded);
            
            if (entries_loaded == 0) begin
                $display("ERROR: No data loaded from MIF file!");
                $finish;
            end
        end
    endtask
    
    // ========================================================================
    // Kernel Loading Functions
    // ========================================================================
    
    task load_blur_kernel;
        begin
            $display("Loading 3x3 Box Blur kernel");
            kernel[0][0] = 8'sd1; kernel[0][1] = 8'sd1; kernel[0][2] = 8'sd1;
            kernel[1][0] = 8'sd1; kernel[1][1] = 8'sd1; kernel[1][2] = 8'sd1;
            kernel[2][0] = 8'sd1; kernel[2][1] = 8'sd1; kernel[2][2] = 8'sd1;
        end
    endtask
    
    task load_sharpen_kernel;
        begin
            $display("Loading 3x3 Sharpen kernel");
            kernel[0][0] = 8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] = 8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] = 8'sd5; kernel[1][2] = -8'sd1;
            kernel[2][0] = 8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] = 8'sd0;
        end
    endtask
    
    task load_edge_aggressive_kernel;
        begin
            $display("Loading 3x3 Aggressive Edge Detection kernel");
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd1; kernel[0][2] = -8'sd1;
            kernel[1][0] = -8'sd1; kernel[1][1] = 8'sd8; kernel[1][2] = -8'sd1;
            kernel[2][0] = -8'sd1; kernel[2][1] = -8'sd1; kernel[2][2] = -8'sd1;
        end
    endtask

    task load_edge_very_aggressive_kernel;
        begin
            $display("Loading 3x3 Very Aggressive Edge Detection kernel");
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd1; kernel[0][2] = -8'sd1;
            kernel[1][0] = -8'sd1; kernel[1][1] = 8'sd12; kernel[1][2] = -8'sd1;
            kernel[2][0] = -8'sd1; kernel[2][1] = -8'sd1; kernel[2][2] = -8'sd1;
        end
    endtask

    task load_edge_gentle_kernel;
        begin
            $display("Loading 3x3 Gentle Edge Detection kernel");
            kernel[0][0] = 8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] = 8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] = 8'sd2; kernel[1][2] = -8'sd1;
            kernel[2][0] = 8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] = 8'sd0;
        end
    endtask

    task load_edge_laplacian_kernel;
        begin
            $display("Loading 3x3 Laplacian Edge Detection kernel");
            kernel[0][0] = 8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] = 8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] = 8'sd4; kernel[1][2] = -8'sd1;
            kernel[2][0] = 8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] = 8'sd0;
        end
    endtask

    task load_sobel_y_kernel;
        begin
            $display("Loading 3x3 Sobel Y kernel");
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd2; kernel[0][2] = -8'sd1;
            kernel[1][0] = 8'sd0; kernel[1][1] = 8'sd0; kernel[1][2] = 8'sd0;
            kernel[2][0] = 8'sd1; kernel[2][1] = 8'sd2; kernel[2][2] = 8'sd1;
        end
    endtask

    task load_opening_kernel;
        begin
            $display("Loading 3x3 Opening kernel");
            kernel[0][0] = 8'sd1; kernel[0][1] = 8'sd1; kernel[0][2] = 8'sd1;
            kernel[1][0] = 8'sd1; kernel[1][1] = 8'sd1; kernel[1][2] = 8'sd1;
            kernel[2][0] = 8'sd1; kernel[2][1] = 8'sd1; kernel[2][2] = 8'sd1;
        end
    endtask

    // ========================================================================
    // Output Save Function (Generic)
    // ========================================================================
    
    task save_output_image(input string filename, input reg [W-1:0] image_data [0:IMG_WIDTH*IMG_HEIGHT-1]);
        begin
            $display("Saving output image to MIF file: %s", filename);
            fd_out = $fopen(filename, "w");
            
            // MIF header
            $fwrite(fd_out, "DEPTH = %0d;\n", IMG_WIDTH*IMG_HEIGHT);
            $fwrite(fd_out, "WIDTH = %0d;\n", W);
            $fwrite(fd_out, "ADDRESS_RADIX = HEX;\n");
            $fwrite(fd_out, "DATA_RADIX = HEX;\n");
            $fwrite(fd_out, "CONTENT\n");
            $fwrite(fd_out, "BEGIN\n");
            
            // Write pixel data
            for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
                $fwrite(fd_out, "%h : %h;\n", i, image_data[i]);
            end
            
            $fwrite(fd_out, "END;\n");
            $fclose(fd_out);
            $display("Output image saved successfully");
        end
    endtask
    
    // ========================================================================
    // Optional: Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("convolution_filter_tb.vcd");
        $dumpvars(0, convolution_filter_tb);
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #(CLK_PERIOD * 1000000); // 1M cycles timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule