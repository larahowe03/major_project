`timescale 1ns/1ps

module convolution_filter_tb;

    // ========================================================================
    // Parameters
    // ========================================================================
    localparam IMG_WIDTH = 640;
    localparam IMG_HEIGHT = 480;
    localparam KERNEL_H = 3;
    localparam KERNEL_W = 3;
    localparam W = 8;
    localparam W_FRAC = 0;
    
    localparam CLK_PERIOD = 10; // 100 MHz
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    logic clk;
    logic rst_n;
    
    logic x_valid;
    logic x_ready;
    logic [W-1:0] x_data;
    
    logic y_valid;
    logic y_ready;
    logic [W-1:0] y_data;
    
    logic signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1];
    
    // ========================================================================
    // Memory for Image Data
    // ========================================================================
    logic [W-1:0] input_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    logic [W-1:0] output_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    
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
        .y_ready(y_ready),
        .y_data(y_data),
        .kernel(kernel)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer pixel_in_count = 0;
    integer pixel_out_count = 0;
    integer fd_out;
    
    // ========================================================================
    // Input Stimulus Process
    // ========================================================================
    initial begin
        // Initialize
        rst_n = 0;
        x_valid = 0;
        x_data = 0;
        y_ready = 1; // Always ready to accept output
        
        // Load input image from MIF file
        $readmemh("tb/PATTERN_RECOGNITION/image_grayscale.mif", input_image);
        $display("Loaded input image from tb/PATTERN_RECOGNITION/image_grayscale.mif");
        
        // Select kernel type (choose one)
        // load_box_blur_kernel();
        load_sharpen_kernel();
        // load_edge_detect_kernel();
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Stream input pixels
        $display("Starting to stream %0d pixels...", IMG_WIDTH*IMG_HEIGHT);
        for (pixel_in_count = 0; pixel_in_count < IMG_WIDTH*IMG_HEIGHT; pixel_in_count++) begin
            x_data = input_image[pixel_in_count];
            x_valid = 1;
            @(posedge clk);
            
            // Wait for handshake
            while (!x_ready) @(posedge clk);
            
            // Optional: Print progress
            if (pixel_in_count % 1000 == 0)
                $display("  Sent pixel %0d/%0d", pixel_in_count, IMG_WIDTH*IMG_HEIGHT);
        end
        
        x_valid = 0;
        $display("Finished sending all input pixels");
        
        // Wait for all outputs
        wait(pixel_out_count >= IMG_WIDTH*IMG_HEIGHT);
        
        // Save output
        repeat(100) @(posedge clk);
        save_output_image();
        
        $display("\n=== TEST COMPLETE ===");
        $display("Input pixels:  %0d", pixel_in_count);
        $display("Output pixels: %0d", pixel_out_count);
        $finish;
    end
    
    // ========================================================================
    // Output Capture Process
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n && y_valid && y_ready) begin
            output_image[pixel_out_count] = y_data;
            pixel_out_count++;
            
            // Optional: Print progress
            if (pixel_out_count % 1000 == 0)
                $display("  Received pixel %0d/%0d", pixel_out_count, IMG_WIDTH*IMG_HEIGHT);
        end
    end
    
    // ========================================================================
    // Kernel Loading Functions
    // ========================================================================
    
    task load_box_blur_kernel();
        begin
            $display("Loading 3x3 Box Blur kernel");
            // Box blur (average): all 1s, divide by 9 in convolution
            kernel[0][0] = 8'sd1; kernel[0][1] = 8'sd1; kernel[0][2] = 8'sd1;
            kernel[1][0] = 8'sd1; kernel[1][1] = 8'sd1; kernel[1][2] = 8'sd1;
            kernel[2][0] = 8'sd1; kernel[2][1] = 8'sd1; kernel[2][2] = 8'sd1;
            // Note: You'll need to divide output by 9 for proper normalization
        end
    endtask
    
    task load_sharpen_kernel();
        begin
            $display("Loading 3x3 Sharpen kernel");
            // Sharpen: [ 0 -1  0; -1 5 -1; 0 -1 0 ]
            kernel[0][0] =  8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] =  8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd5; kernel[1][2] = -8'sd1;
            kernel[2][0] =  8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] =  8'sd0;
        end
    endtask
    
    task load_edge_detect_kernel();
        begin
            $display("Loading 3x3 Edge Detection kernel");
            // Sobel-like edge detection
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd1; kernel[0][2] = -8'sd1;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd8; kernel[1][2] = -8'sd1;
            kernel[2][0] = -8'sd1; kernel[2][1] = -8'sd1; kernel[2][2] = -8'sd1;
        end
    endtask
    
    // ========================================================================
    // Output Save Function
    // ========================================================================
    
    task save_output_image();
        integer i;
        begin
            $display("Saving output image to output_image.mif");
            fd_out = $fopen("output_image.mif", "w");
            
            // MIF header
            $fwrite(fd_out, "DEPTH = %0d;\n", IMG_WIDTH*IMG_HEIGHT);
            $fwrite(fd_out, "WIDTH = %0d;\n", W);
            $fwrite(fd_out, "ADDRESS_RADIX = HEX;\n");
            $fwrite(fd_out, "DATA_RADIX = HEX;\n");
            $fwrite(fd_out, "CONTENT\n");
            $fwrite(fd_out, "BEGIN\n");
            
            // Write pixel data
            for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i++) begin
                $fwrite(fd_out, "%h : %h;\n", i, output_image[i]);
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