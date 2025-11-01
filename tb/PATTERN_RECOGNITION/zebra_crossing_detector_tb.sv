`timescale 1ns / 1ps

module zebra_crossing_detector_tb;

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
    logic [$clog2(TOTAL_PIXELS)-1:0] bram_addr;
    logic [1:0] bram_data;
    
    // Visited BRAM signals
    logic [$clog2(TOTAL_PIXELS)-1:0] mark_visited_addr;
    logic mark_visited_we;
    
    // Test image memory (loaded from MIF)
    logic [1:0] test_image [0:TOTAL_PIXELS-1];
    
    // ========================================================================
    // Clock generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // ========================================================================
    // Load test image from MIF file (MIF parser version)
    // ========================================================================

    initial begin
        load_mif_file("test_img_conv.mif");
        $display("Total pixels: %0d", TOTAL_PIXELS);
    end

    // ------------------------------------------------------------------------
    // MIF File Loader Task
    // ------------------------------------------------------------------------
    task load_mif_file(input string filename);
        integer fd, status, addr, data;
        integer entries_loaded;
        reg [200*8:1] line;
        integer colon_pos, i_char;
        begin
            fd = $fopen(filename, "r");
            if (fd == 0) begin
                $display("ERROR: Cannot open file %s", filename);
                $finish;
            end

            $display("Parsing MIF file: %s", filename);
            entries_loaded = 0;
            
            // Read line by line
            while (!$feof(fd)) begin
                status = $fgets(line, fd);
                if (status == 0) continue;
                
                // Skip header and END lines
                if (line[8*3 +: 24] == "DEP" || line[8*3 +: 24] == "WID" ||
                    line[8*3 +: 24] == "ADD" || line[8*3 +: 24] == "DAT" ||
                    line[8*3 +: 24] == "CON" || line[8*3 +: 24] == "BEG" ||
                    line[8*3 +: 24] == "END")
                    continue;

                // Try to parse lines like "00010 : 7F;"
                status = $sscanf(line, "%h : %h;", addr, data);
                if (status == 2 && addr < TOTAL_PIXELS) begin
                    // Threshold: treat as binary image — if nonzero pixel, mark white (2'b01)
                    test_image[addr] = (data != 0) ? 2'b01 : 2'b00;
                    entries_loaded++;
                    
                    if (entries_loaded <= 5)
                        $display("  addr=%0h data=%0h => %b", addr, data, test_image[addr]);
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
    // Image BRAM simulation
    // ========================================================================

    initial bram_data = 2'b00;
    always @(posedge clk) begin
        // Mark visited (write port)
        if (mark_visited_we && mark_visited_addr < TOTAL_PIXELS)
            test_image[mark_visited_addr] <= 2'b10; // Mark as visited

        // Read port (read-only for DUT)
        if (bram_addr < TOTAL_PIXELS)
            bram_data <= test_image[bram_addr];
        else
            bram_data <= 2'b00;
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
        .bram_addr(bram_addr),
        .bram_data(bram_data),
        .mark_visited_addr(mark_visited_addr),
        .mark_visited_we(mark_visited_we)
    );
    
    // ========================================================================
    // Test stimulus (unchanged)
    // ========================================================================
    initial begin
        rst_n = 0;
        valid_to_read = 0;
        
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        $display("\n========================================");
        $display("Starting zebra crossing detection...");
        $display("========================================\n");
        
        valid_to_read = 1;
        
        wait(detection_valid);
        #(CLK_PERIOD);
        
        $display("\n========================================");
        $display("Detection Complete!");
        $display("========================================");
        $display("Stripes found: %0d", stripe_count);
        $display("Zebra crossing detected: %s", crossing_detected ? "YES" : "NO");
        $display("========================================\n");
        
        #(CLK_PERIOD * 20);
        
        if (crossing_detected && stripe_count >= 3)
            $display("✓ TEST PASSED: Zebra crossing detected with %0d stripes", stripe_count);
        else
            $display("✗ TEST FAILED: Expected zebra crossing detection");
        
        $finish;
    end
    
    // ========================================================================
    // Timeout watchdog
    // ========================================================================
    initial begin
        #(CLK_PERIOD * 10_000_000);
        $display("\n✗ ERROR: Simulation timeout!");
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
    // Waveform dump
    // ========================================================================
    initial begin
        $dumpfile("zebra_detector.vcd");
        $dumpvars(0, zebra_crossing_detector_tb);
    end
    
    // ========================================================================
    // Optional: Save visited map
    // ========================================================================
    task save_visited_map;
        integer file;
        file = $fopen("visited_map.pbm", "w");
        $fwrite(file, "P1\n%0d %0d\n", IMG_WIDTH, IMG_HEIGHT);
        for (int y = 0; y < IMG_HEIGHT; y++) begin
            for (int x = 0; x < IMG_WIDTH; x++) begin
                $fwrite(file, "%0d ", (test_image[y * IMG_WIDTH + x] == 2'b10) ? 1 : 0);
            end
            $fwrite(file, "\n");
        end
        $fclose(file);
        $display("Visited map saved to visited_map.pbm");
    endtask
    
    always @(posedge detection_valid) begin
        #(CLK_PERIOD * 2);
        save_visited_map();
    end

endmodule
