`timescale 1ns / 1ps

module tb_zebra_crossing_detector;

    // Parameters
    localparam IMG_WIDTH = 640;
    localparam IMG_HEIGHT = 480;
    localparam TOTAL_PIXELS = IMG_WIDTH * IMG_HEIGHT;
    localparam MIN_EDGE_LENGTH = 50;
    localparam CLK_PERIOD = 20;  // 50MHz
    
    // DUT signals
    logic clk;
    logic rst_n;
    logic valid_to_read;
    logic detection_valid;
    logic crossing_detected;
    logic [7:0] stripe_count;
    
    // Image BRAM signals
    logic [$clog2(TOTAL_PIXELS)-1:0] pixel_addr;
    logic pixel_data;
    
    // Visited BRAM signals
    logic [$clog2(TOTAL_PIXELS)-1:0] visited_addr;
    logic visited_we;
    logic visited_wdata;
    logic visited_rdata;
    
    // Test image memory (loaded from MIF)
    logic test_image [0:TOTAL_PIXELS-1];
    
    // Visited memory for testbench
    logic visited_mem [0:TOTAL_PIXELS-1];
    
    // ========================================================================
    // Clock generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========================================================================
    // Load test image from MIF file
    // ========================================================================
	 // Count white pixels
    integer white_count = 0;

	 initial begin
        // Load binary MIF file
        $readmemb("test_img.mif", test_image);
        $display("Loaded test image from test_img.mif");
        
        for (int i = 0; i < TOTAL_PIXELS; i++) begin
            if (test_image[i] == 1'b1) white_count++;
        end
        $display("Total pixels: %0d", TOTAL_PIXELS);
        $display("White pixels: %0d (%0.2f%%)", white_count, 
                 100.0 * white_count / TOTAL_PIXELS);
    end
    
    // ========================================================================
    // Image BRAM simulation (read-only)
    // ========================================================================
    always_ff @(posedge clk) begin
        if (pixel_addr < TOTAL_PIXELS) begin
            pixel_data <= test_image[pixel_addr];
        end else begin
            pixel_data <= 1'b0;
        end
    end
    
    // ========================================================================
    // Visited BRAM simulation (read/write)
    // ========================================================================
    initial begin
        // Initialize visited memory to 0
        for (int i = 0; i < TOTAL_PIXELS; i++) begin
            visited_mem[i] = 1'b0;
        end
    end
    
    always_ff @(posedge clk) begin
        // Write port
        if (visited_we) begin
            visited_mem[visited_addr] <= visited_wdata;
        end
        
        // Read port
        if (visited_addr < TOTAL_PIXELS) begin
            visited_rdata <= visited_mem[visited_addr];
        end else begin
            visited_rdata <= 1'b0;
        end
    end
    
    // ========================================================================
    // DUT instantiation
    // ========================================================================
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MIN_EDGE_LENGTH(MIN_EDGE_LENGTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        .detection_valid(detection_valid),
        .crossing_detected(crossing_detected),
        .stripe_count(stripe_count),
        .pixel_addr(pixel_addr),
        .pixel_data(pixel_data),
        .visited_addr(visited_addr),
        .visited_we(visited_we),
        .visited_wdata(visited_wdata),
        .visited_rdata(visited_rdata)
    );
    
    // ========================================================================
    // Test stimulus
    // ========================================================================
    initial begin
        // Initialize
        rst_n = 0;
        valid_to_read = 0;
        
        // Wait and reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        $display("\n========================================");
        $display("Starting zebra crossing detection...");
        $display("========================================\n");
        
        // Start detection
        valid_to_read = 1;
        
        // Wait for detection to complete
        wait(detection_valid);
        #(CLK_PERIOD);
        
        $display("\n========================================");
        $display("Detection Complete!");
        $display("========================================");
        $display("Stripes found: %0d", stripe_count);
        $display("Zebra crossing detected: %s", crossing_detected ? "YES" : "NO");
        $display("========================================\n");
        
        // Additional cycles for waveform viewing
        #(CLK_PERIOD * 20);
        
        // End simulation
        if (crossing_detected && stripe_count >= 3) begin
            $display("✓ TEST PASSED: Zebra crossing detected with %0d stripes", stripe_count);
        end else begin
            $display("✗ TEST FAILED: Expected zebra crossing detection");
        end
        
        $finish;
    end
    
    // ========================================================================
    // Timeout watchdog
    // ========================================================================
    initial begin
        // Timeout after reasonable time (adjust based on expected runtime)
        #(CLK_PERIOD * 10_000_000);  // 200ms at 50MHz
        $display("\n✗ ERROR: Simulation timeout!");
        $display("Detection did not complete in expected time.");
        $finish;
    end
    
    // ========================================================================
    // Progress monitoring
    // ========================================================================
    integer last_stripe_count = 0;
    always @(posedge clk) begin
        if (stripe_count != last_stripe_count) begin
            $display("[Time %0t] Stripe #%0d detected", $time, stripe_count);
            last_stripe_count = stripe_count;
        end
    end
    
    // ========================================================================
    // Waveform dump (for viewing in GTKWave/ModelSim)
    // ========================================================================
    initial begin
        $dumpfile("zebra_detector.vcd");
        $dumpvars(0, tb_zebra_crossing_detector);
    end
    
    // ========================================================================
    // Optional: Save visited map for debugging
    // ========================================================================
    task save_visited_map;
        integer file;
        file = $fopen("visited_map.pbm", "w");
        $fwrite(file, "P1\n%0d %0d\n", IMG_WIDTH, IMG_HEIGHT);
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            for (int x = 0; x < IMG_WIDTH; x++) begin
                $fwrite(file, "%0d ", visited_mem[y * IMG_WIDTH + x]);
            end
            $fwrite(file, "\n");
        end
        $fclose(file);
        $display("Visited map saved to visited_map.pbm");
    endtask
    
    // Save visited map after detection completes
    always @(posedge detection_valid) begin
        #(CLK_PERIOD * 2);
        save_visited_map();
    end

endmodule