`timescale 1ns/1ps

module zebra_crossing_tb;

    // ========================================================================
    // Parameters
    // ========================================================================
    parameter IMG_WIDTH = 640;
    parameter IMG_HEIGHT = 480;
    parameter W = 8;
    
    parameter CLK_PERIOD = 20; // 50 MHz
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    reg clk;
    reg rst_n;
    
    reg pixel_valid;
    reg [W-1:0] edge_pixel;
    
    wire crossing_detected;
    wire detection_valid;
    wire [7:0] stripe_count;
    wire [15:0] confidence;
    
    // ========================================================================
    // Memory for Edge-Detected Image Data
    // ========================================================================
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
        .W(W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .edge_pixel(edge_pixel),
        .crossing_detected(crossing_detected),
        .detection_valid(detection_valid),
        .stripe_count(stripe_count),
        .confidence(confidence)
    );
    
    // ========================================================================
    // Test Variables
    // ========================================================================
    integer pixel_count;
    integer num_detections;
    integer i;
    
    // ========================================================================
    // Input Stimulus Process
    // ========================================================================
    initial begin
        // Initialize
        pixel_count = 0;
        num_detections = 0;
        rst_n = 0;
        pixel_valid = 0;
        edge_pixel = 0;
        
        $display("\n========================================");
        $display("ZEBRA CROSSING DETECTION TEST");
        $display("(Using Pre-computed Edge Image)");
        $display("========================================\n");
        
        // Load pre-computed edge-detected image from MIF file
        load_edge_mif_file;
        $display("Loaded edge image: %0d x %0d = %0d pixels\n", IMG_WIDTH, IMG_HEIGHT, IMG_WIDTH*IMG_HEIGHT);
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        @(posedge clk);
        
        // Stream edge-detected pixels to detector
        $display("Streaming edge-detected image to detector...");
        for (pixel_count = 0; pixel_count < IMG_WIDTH*IMG_HEIGHT; pixel_count = pixel_count + 1) begin
            edge_pixel = edge_image[pixel_count];
            pixel_valid = 1;
            
            @(posedge clk);
            
            // Print progress
            if (pixel_count % 50000 == 0)
                $display("  Streamed %0d/%0d pixels", pixel_count, IMG_WIDTH*IMG_HEIGHT);
        end
        
        pixel_valid = 0;
        $display("Finished streaming all pixels\n");
        
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
            $display("Confidence: %0d/255", confidence);
        end else begin
            $display("No detection signal received!");
        end
        $display("========================================\n");
        
        $display("Test complete!");
        $finish;
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
            $display("  Confidence: %0d/255", confidence);
            $display("  Timestamp: %0t", $time);
            
            if (crossing_detected) begin
                $display("  >>> ZEBRA CROSSING FOUND! <<<");
            end
        end
    end
    
    // ========================================================================
    // MIF File Loader for Edge-Detected Image
    // ========================================================================
    
    task load_edge_mif_file;
        integer fd, status, addr, data;
        integer entries_loaded;
        reg [200*8:1] line;
        integer colon_pos, i_char;
        begin
            // Try to open edge-detected MIF file (output from convolution)
            fd = $fopen("positive_case.mif", "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open file positive_case.mif");
                $display("Please run the convolution filter first to generate edge-detected image!");
                $finish;
            end
            
            entries_loaded = 0;
            
            // Read line by line
            while (!$feof(fd)) begin
                status = $fgets(line, fd);
                if (status == 0) continue;
                
                // Look for colon
                colon_pos = -1;
                for (i_char = 1; i_char <= 200*8; i_char = i_char + 8) begin
                    if (line[i_char+:8] == ":") begin
                        colon_pos = i_char;
                        i_char = 200*8 + 8;
                    end
                end
                
                if (colon_pos > 0) begin
                    status = $sscanf(line, "%h:%h", addr, data);
                    if (status == 2 && addr < IMG_WIDTH*IMG_HEIGHT) begin
                        edge_image[addr] = data[W-1:0];
                        entries_loaded = entries_loaded + 1;
                        
                        // Show first few entries for debug
                        if (entries_loaded <= 5) begin
                            $display("  addr=%h data=%h", addr, data);
                        end
                    end
                end
            end
            
            $fclose(fd);
            $display("Edge MIF loading complete. Loaded %0d entries.", entries_loaded);
            
            if (entries_loaded == 0) begin
                $display("ERROR: No data loaded from MIF file!");
                $finish;
            end
        end
    endtask
    
    // ========================================================================
    // Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("zebra_crossing_tb.vcd");
        $dumpvars(0, zebra_crossing_tb);
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