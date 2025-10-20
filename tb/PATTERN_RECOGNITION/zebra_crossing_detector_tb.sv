`timescale 1ns/1ps

module zebra_crossing_detector_tb;

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
    
    reg signed [W-1:0] kernel [0:KERNEL_H-1][0:KERNEL_W-1];
    
    wire crossing_detected;
    wire detection_valid;
    wire [7:0] stripe_count;
    wire [15:0] confidence;
    
    wire y_valid;
    reg y_ready;
    wire [W-1:0] y_data;
    
    // ========================================================================
    // Memory for Image Data
    // ========================================================================
    reg [W-1:0] input_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    reg [W-1:0] edge_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    
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
    zebra_crossing_detector #(
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
        .kernel(kernel),
        .crossing_detected(crossing_detected),
        .detection_valid(detection_valid),
        .stripe_count(stripe_count),
        .y_valid(y_valid),
        .y_ready(y_ready),
        .y_data(y_data)
    );
    
    // Add confidence output (need to tap into detector module)
    // For now, we'll monitor stripe_count as a proxy
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer pixel_in_count;
    integer pixel_out_count;
    integer i;
    integer num_detections;
    integer num_true_positives;
    
    // ========================================================================
    // Input Stimulus Process
    // ========================================================================
    initial begin
        // Initialize
        pixel_in_count = 0;
        pixel_out_count = 0;
        num_detections = 0;
        num_true_positives = 0;
        rst_n = 0;
        x_valid = 0;
        x_data = 0;
        y_ready = 1; // Always ready to accept output
        
        // Initialize edge image
        for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
            edge_image[i] = 8'h00;
        end
        
        $display("\n========================================");
        $display("ZEBRA CROSSING DETECTION TEST");
        $display("========================================\n");
        
        // Load input image from MIF file
        load_mif_file();
        $display("Loaded input image: %0d x %0d = %0d pixels\n", IMG_WIDTH, IMG_HEIGHT, IMG_WIDTH*IMG_HEIGHT);
        
        // Load edge detection kernel
        load_edge_aggressive_kernel();
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Stream input pixels
        $display("Processing image through edge detection...");
        for (pixel_in_count = 0; pixel_in_count < IMG_WIDTH*IMG_HEIGHT; pixel_in_count = pixel_in_count + 1) begin
            x_data = input_image[pixel_in_count];
            x_valid = 1;
            
            // Wait for handshake
            @(posedge clk);
            while (!x_ready) @(posedge clk);
            
            // Print progress
            if (pixel_in_count % 50000 == 0)
                $display("  Processed %0d/%0d pixels", pixel_in_count, IMG_WIDTH*IMG_HEIGHT);
        end
        
        x_valid = 0;
        $display("Finished processing all pixels\n");
        
        // Wait for detection to complete
        repeat(100) @(posedge clk);
        
        // Display results
        $display("========================================");
        $display("DETECTION RESULTS");
        $display("========================================");
        $display("Total detections triggered: %0d", num_detections);
        if (num_detections > 0) begin
            $display("Crossing detected: %s", crossing_detected ? "YES" : "NO");
            $display("Stripe count: %0d", stripe_count);
        end else begin
            $display("No detection signal received!");
        end
        $display("========================================\n");
        
        // Save edge-detected image for inspection
        save_edge_image();
        
        $display("Test complete!");
        $finish;
    end
    
    // ========================================================================
    // Edge Image Capture Process
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n && y_valid && y_ready) begin
            if (pixel_out_count < IMG_WIDTH*IMG_HEIGHT) begin
                edge_image[pixel_out_count] = y_data;
            end
            pixel_out_count = pixel_out_count + 1;
        end
    end
    
    // ========================================================================
    // Detection Monitoring
    // ========================================================================
    always @(posedge clk) begin
        if (rst_n && detection_valid) begin
            num_detections = num_detections + 1;
            $display("\n[DETECTION EVENT #%0d]", num_detections);
            $display("  Crossing detected: %s", crossing_detected ? "YES" : "NO");
            $display("  Stripe count: %0d", stripe_count);
            $display("  Timestamp: %0t", $time);
            
            if (crossing_detected) begin
                $display("  >>> ZEBRA CROSSING FOUND! <<<");
                num_true_positives = num_true_positives + 1;
            end
        end
    end
    
    // ========================================================================
    // MIF File Loader
    // ========================================================================
    
    task load_mif_file;
        integer fd, status, addr, data, c;
        integer entries_loaded;
        reg [200*8:1] line;
        integer colon_pos, i_char;
        begin
            fd = $fopen("image_grayscale.mif", "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open file image_grayscale.mif");
                $finish;
            end
            
            $display("Parsing MIF file: image_grayscale.mif");
            entries_loaded = 0;
            
            // Read line by line
            while (!$feof(fd)) begin
                // Read a line
                status = $fgets(line, fd);
                if (status == 0) continue;
                
                // Try to parse "addr:data;" format
                // Look for colon in the line
                colon_pos = -1;
                for (i_char = 1; i_char <= 200*8; i_char = i_char + 8) begin
                    if (line[i_char+:8] == ":") begin
                        colon_pos = i_char;
                        i_char = 200*8 + 8; // break
                    end
                end
                
                if (colon_pos > 0) begin
                    // Try to extract address and data
                    status = $sscanf(line, "%h:%h", addr, data);
                    if (status == 2 && addr < IMG_WIDTH*IMG_HEIGHT) begin
                        input_image[addr] = data[W-1:0];
                        entries_loaded = entries_loaded + 1;
                        
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
    // Kernel Loading
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
            kernel[0][0] =  8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] =  8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd5; kernel[1][2] = -8'sd1;
            kernel[2][0] =  8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] =  8'sd0;
        end
    endtask
    
    task load_edge_aggressive_kernel;
        begin
            $display("Loading 3x3 Aggressive Edge Detection kernel");
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd1; kernel[0][2] = -8'sd1;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd8; kernel[1][2] = -8'sd1;
            kernel[2][0] = -8'sd1; kernel[2][1] = -8'sd1; kernel[2][2] = -8'sd1;
        end
    endtask

    task load_edge_very_aggressive_kernel;
        begin
            $display("Loading 3x3 Very Aggressive Edge Detection kernel");
            kernel[0][0] = -8'sd1; kernel[0][1] = -8'sd1; kernel[0][2] = -8'sd1;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd12; kernel[1][2] = -8'sd1;
            kernel[2][0] = -8'sd1; kernel[2][1] = -8'sd1; kernel[2][2] = -8'sd1;
        end
    endtask

    task load_edge_gentle_kernel;
        begin
            $display("Loading 3x3 Gentle Edge Detection kernel");
            kernel[0][0] =  8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] =  8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd2; kernel[1][2] = -8'sd1;
            kernel[2][0] =  8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] =  8'sd0;
        end
    endtask

    task load_edge_laplacian_kernel;
        begin
            $display("Loading 3x3 Laplacian Edge Detection kernel");
            kernel[0][0] =  8'sd0; kernel[0][1] = -8'sd1; kernel[0][2] =  8'sd0;
            kernel[1][0] = -8'sd1; kernel[1][1] =  8'sd4; kernel[1][2] = -8'sd1;
            kernel[2][0] =  8'sd0; kernel[2][1] = -8'sd1; kernel[2][2] =  8'sd0;
        end
    endtask
    
    // ========================================================================
    // Save Edge Image
    // ========================================================================
    
    task save_edge_image;
        integer fd_out;
        begin
            $display("\nSaving edge-detected image to edge_output.mif");
            fd_out = $fopen("edge_output.mif", "w");
            
            // MIF header
            $fwrite(fd_out, "DEPTH = %0d;\n", IMG_WIDTH*IMG_HEIGHT);
            $fwrite(fd_out, "WIDTH = %0d;\n", W);
            $fwrite(fd_out, "ADDRESS_RADIX = HEX;\n");
            $fwrite(fd_out, "DATA_RADIX = HEX;\n");
            $fwrite(fd_out, "CONTENT\n");
            $fwrite(fd_out, "BEGIN\n");
            
            // Write pixel data
            for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i = i + 1) begin
                $fwrite(fd_out, "%h : %h;\n", i, edge_image[i]);
            end
            
            $fwrite(fd_out, "END;\n");
            $fclose(fd_out);
            $display("Edge image saved successfully");
        end
    endtask
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("zebra_crossing_tb.vcd");
        $dumpvars(0, zebra_crossing_detector_tb);
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #(CLK_PERIOD * 2000000); // 2M cycles timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule