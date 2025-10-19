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
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    reg clk;
    reg rst_n;
    
    reg x_valid;
    wire x_ready;
    reg [W-1:0] x_data;
    
    wire y_valid;
    reg y_ready;
    wire [W-1:0] y_data;
    
    reg signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1];
    
    // ========================================================================
    // Memory for Image Data
    // ========================================================================
    reg [W-1:0] input_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    reg [W-1:0] output_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    
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
    integer pixel_in_count;
    integer pixel_out_count;
    integer fd_out;
    integer i;
    
    // ========================================================================
    // Input Stimulus Process
    // ========================================================================
    initial begin
        // Initialize
        pixel_in_count = 0;
        pixel_out_count = 0;
        rst_n = 0;
        x_valid = 0;
        x_data = 0;
        y_ready = 1; // Always ready to accept output
        
        // Initialize output image to white
        for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
            output_image[i] = 8'hFF;
        end
        
        // Load input image from MIF file
        load_mif_file("image_grayscale.mif");
        $display("Loaded input image: %0d x %0d = %0d pixels", IMG_WIDTH, IMG_HEIGHT, IMG_WIDTH*IMG_HEIGHT);
        
        // Select kernel type
        load_edge_detect_kernel();
        
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
        
        // Wait for all outputs (with timeout)
        fork
            begin
                wait(pixel_out_count >= IMG_WIDTH*IMG_HEIGHT);
                $display("All output pixels received!");
            end
            begin
                #(CLK_PERIOD * 500000); // 500k cycles timeout
                $display("WARNING: Timeout waiting for outputs. Received %0d/%0d pixels", 
                         pixel_out_count, IMG_WIDTH*IMG_HEIGHT);
            end
        join
        disable fork;
        
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
            if (pixel_out_count < IMG_WIDTH*IMG_HEIGHT) begin
                output_image[pixel_out_count] = y_data;
            end
            pixel_out_count = pixel_out_count + 1;
            
            // Print progress
            if (pixel_out_count % 50000 == 0)
                $display("  Received pixel %0d/%0d", pixel_out_count, IMG_WIDTH*IMG_HEIGHT);
        end
    end
    
    // ========================================================================
    // MIF File Loader (Simple C-style parsing)
    // ========================================================================
    
    task load_mif_file;
        input [8*100:1] filename; // String parameter
        integer fd, status, addr, data, c;
        integer entries_loaded;
        begin
            fd = $fopen(filename, "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open file %s", filename);
                $finish;
            end
            
            $display("Parsing MIF file: %s", filename);
            entries_loaded = 0;
            
            // Simple state machine to parse "addr : data;" format
            // $fscanf automatically skips non-numeric text like "WIDTH", "BEGIN", etc.
            while (!$feof(fd)) begin
                // Try to read address (hex)
                status = $fscanf(fd, "%h", addr);
                if (status != 1) begin
                    // Skip character and try again
                    c = $fgetc(fd);
                    continue;
                end
                
                // Look for colon separator
                while (!$feof(fd)) begin
                    c = $fgetc(fd);
                    if (c == ":") begin
                        c = ":";
                        disable label1;
                    end
                    if (c == ";" || c == "\n") begin
                        disable label1;
                    end
                    begin: label1 end
                end
                
                if (c != ":") continue; // Restart if we didn't find colon
                
                // Read data value (hex)
                status = $fscanf(fd, "%h", data);
                if (status == 1 && addr < IMG_WIDTH*IMG_HEIGHT) begin
                    input_image[addr] = data[W-1:0];
                    entries_loaded = entries_loaded + 1;
                end
                
                // Skip to semicolon or newline
                while (!$feof(fd)) begin
                    c = $fgetc(fd);
                    if (c == ";" || c == "\n") begin
                        disable label2;
                    end
                    begin: label2 end
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
    
    task load_box_blur_kernel;
        begin
            $display("Loading 3x3 Box Blur kernel");
            // Box blur (average): all 1s, divide by 9 in convolution
            kernel[0][0] = 8'sd1; kernel[0][1] = 8'sd1; kernel[0][2] = 8'sd1;
            kernel[1][0] = 8'sd1; kernel[1][1] = 8'sd1; kernel[1][2] = 8'sd1;
            kernel[2][0] = 8'sd1; kernel[2][1] = 8'sd1; kernel[2][2] = 8'sd1;
        end
    endtask
    
    task load_sharpen_kernel;
        begin
            $display("Loading 3x3 Sharpen kernel");
            // Sharpen: [ 0 -1  0; -1 5 -1; 0 -1 0 ]
            kernel[0][0] =  8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] =  8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd5; kernel[1][2] = -8'sd1;
            kernel[2][0] =  8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] =  8'sd0;
        end
    endtask
    
    task load_edge_detect_kernel;
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
    
    task save_output_image;
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
            for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
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