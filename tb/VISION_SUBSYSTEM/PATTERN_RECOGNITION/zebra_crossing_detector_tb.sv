`timescale 1ns / 1ps

module zebra_crossing_detector_tb;

    // Parameters
    localparam IMG_WIDTH = 320;
    localparam IMG_HEIGHT = 240;
    localparam MAX_EDGES = 2048;
    localparam MIN_WHITE_PIXELS = 15360;
    localparam MAX_WHITE_PIXELS = 53760;
    localparam MIN_EDGE_PIXELS = 1000;
    localparam MIN_CONNECTED_EDGE_PIXELS = 20;
    localparam MIN_CONNECTED_EDGE_INSTANCES = 10;
    localparam MIN_LOWEST_EDGE_Y = IMG_HEIGHT * 4 / 5;  // 192 for 240 height
    
    localparam string EDGE_IMG_FILE = "blur_edge_image.mif";
    localparam string THRESHOLD_IMG_FILE = "blur_thresholded_image.mif";
    localparam string RESULTS_FILE = "detection_results.txt";
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Control signals
    logic valid_to_read;
    
    // Edge list interface
    logic [$clog2(MAX_EDGES)-1:0] edge_read_idx;
    logic [$clog2(IMG_WIDTH)-1:0] edge_x;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_y;
    logic edge_valid;
    logic [$clog2(MAX_EDGES)-1:0] num_edges;
    
    // White pixel counts
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels;
    logic white_count_valid;
    
    // Detection outputs
    logic num_threshold_pixels_fulfilled;
    logic num_edge_pixels_fulfilled;
    logic num_connected_edge_instances_fulfilled;
    logic lowest_edge_position_fulfilled;
    logic capture_trigger;
    
    // Test data structures
    typedef struct packed {
        logic [$clog2(IMG_WIDTH)-1:0] x;
        logic [$clog2(IMG_HEIGHT)-1:0] y;
    } coord_t;
    
    // Image data storage - use constants for array dimensions
    logic [7:0] edge_image [0:IMG_HEIGHT-1][0:IMG_WIDTH-1];
    logic [7:0] threshold_image [0:IMG_HEIGHT-1][0:IMG_WIDTH-1];
    
    // Edge list storage (simulates sparse edge storage)
    coord_t edge_list [0:MAX_EDGES-1];
    logic [$clog2(MAX_EDGES)-1:0] total_edges;
    
    // Statistics
    int white_edge_count;
    int white_threshold_count;
    
    // Instantiate DUT
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_EDGES(MAX_EDGES),
        .MIN_WHITE_PIXELS(MIN_WHITE_PIXELS),
        .MAX_WHITE_PIXELS(MAX_WHITE_PIXELS),
        .MIN_EDGE_PIXELS(MIN_EDGE_PIXELS),
        .MIN_CONNECTED_EDGE_PIXELS(MIN_CONNECTED_EDGE_PIXELS),
        .MIN_CONNECTED_EDGE_INSTANCES(MIN_CONNECTED_EDGE_INSTANCES),
        .MIN_LOWEST_EDGE_Y(MIN_LOWEST_EDGE_Y)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        .edge_read_idx(edge_read_idx),
        .edge_x(edge_x),
        .edge_y(edge_y),
        .edge_valid(edge_valid),
        .num_edges(num_edges),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid),
        .num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
        .num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
        .num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
        .lowest_edge_position_fulfilled(lowest_edge_position_fulfilled),
        .capture_trigger(capture_trigger)
    );
    
    // Clock generation - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Edge list read interface simulation (behaves like BRAM)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_x <= '0;
            edge_y <= '0;
            edge_valid <= 1'b0;
        end else begin
            if (edge_read_idx < total_edges) begin
                edge_x <= edge_list[edge_read_idx].x;
                edge_y <= edge_list[edge_read_idx].y;
                edge_valid <= 1'b1;
            end else begin
                edge_x <= '0;
                edge_y <= '0;
                edge_valid <= 1'b0;
            end
        end
    end
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        valid_to_read = 0;
        white_count_valid = 0;
        num_white_edge_pixels = 0;
        num_white_threshold_pixels = 0;
        total_edges = 0;
        white_edge_count = 0;
        white_threshold_count = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("==========================================================");
        $display("     Zebra Crossing Detector Testbench");
        $display("==========================================================");
        $display("Time: %0t - Starting test", $time);
        $display("");
        
        // Load images
        load_edge_image();
        load_threshold_image();
        
        // Build edge list from edge image
        build_edge_list();
        
        // Count white pixels in both images
        count_white_pixels();
        
        // Test 1: Basic detection with good zebra crossing
        test_zebra_detection();
        
        // Test 2: Test with insufficient edges
        test_insufficient_edges();
        
        // Test 3: Test with edges in wrong position
        test_wrong_position();
        
        // Test 4: Test with too few white pixels
        test_insufficient_white_pixels();
        
        // Save results
        save_results();
        
        $display("");
        $display("==========================================================");
        $display("Time: %0t - All tests completed!", $time);
        $display("==========================================================");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Task: Load edge image from MIF
    task automatic load_edge_image();
        integer fd, addr, data, pixels_loaded;
        int x, y;
        string line;
        
        $display("--- Loading Edge Image ---");
        $display("Time: %0t - Reading from %s", $time, EDGE_IMG_FILE);
        
        fd = $fopen(EDGE_IMG_FILE, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", EDGE_IMG_FILE);
            $finish;
        end
        
        // Skip header until CONTENT BEGIN
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 6) == "CONTENT") break;
        end
        $fgets(line, fd);  // Skip BEGIN
        
        pixels_loaded = 0;
        y = 0;
        x = 0;
        
        // Read data
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 2) == "END") break;
            
            if ($sscanf(line, "%h : %h", addr, data) == 2) begin
                edge_image[y][x] = data[7:0];
                pixels_loaded++;
                
                x++;
                if (x >= IMG_WIDTH) begin
                    x = 0;
                    y++;
                end
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - Edge image loaded: %0d pixels", $time, pixels_loaded);
    endtask
    
    // Task: Load threshold image from MIF
    task automatic load_threshold_image();
        integer fd, addr, data, pixels_loaded;
        int x, y;
        string line;
        
        $display("\n--- Loading Threshold Image ---");
        $display("Time: %0t - Reading from %s", $time, THRESHOLD_IMG_FILE);
        
        fd = $fopen(THRESHOLD_IMG_FILE, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", THRESHOLD_IMG_FILE);
            $finish;
        end
        
        // Skip header until CONTENT BEGIN
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 6) == "CONTENT") break;
        end
        $fgets(line, fd);  // Skip BEGIN
        
        pixels_loaded = 0;
        y = 0;
        x = 0;
        
        // Read data
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 2) == "END") break;
            
            if ($sscanf(line, "%h : %h", addr, data) == 2) begin
                threshold_image[y][x] = data[7:0];
                pixels_loaded++;
                
                x++;
                if (x >= IMG_WIDTH) begin
                    x = 0;
                    y++;
                end
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - Threshold image loaded: %0d pixels", $time, pixels_loaded);
    endtask
    
    // Task: Build edge list from edge image
    task automatic build_edge_list();
        int x, y, edge_count;
        
        $display("\n--- Building Edge List ---");
        $display("Time: %0t - Extracting edge coordinates", $time);
        
        edge_count = 0;
        
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                if (edge_image[y][x] == 8'd255) begin
                    if (edge_count < MAX_EDGES) begin
                        edge_list[edge_count] = '{x: x, y: y};
                        edge_count++;
                    end else begin
                        $warning("Edge list full at %0d edges", MAX_EDGES);
                        break;
                    end
                end
            end
            if (edge_count >= MAX_EDGES) break;
        end
        
        total_edges = edge_count;
        num_edges = edge_count;
        
        $display("Time: %0t - Edge list built: %0d edges", $time, total_edges);
        
        // Show some sample edges
        if (total_edges > 0) begin
            $display("  Sample edges:");
            for (int i = 0; i < 5 && i < total_edges; i++) begin
                $display("    Edge %0d: (%0d, %0d)", i, edge_list[i].x, edge_list[i].y);
            end
        end
    endtask
    
    // Task: Count white pixels in both images
    task automatic count_white_pixels();
        int x, y;
        
        $display("\n--- Counting White Pixels ---");
        
        white_edge_count = 0;
        white_threshold_count = 0;
        
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                if (edge_image[y][x] == 8'd255) begin
                    white_edge_count++;
                end
                if (threshold_image[y][x] == 8'd255) begin
                    white_threshold_count++;
                end
            end
        end
        
        $display("Time: %0t - Edge white pixels: %0d", $time, white_edge_count);
        $display("Time: %0t - Threshold white pixels: %0d", $time, white_threshold_count);
        $display("  Min required edge pixels: %0d", MIN_EDGE_PIXELS);
        $display("  Min required threshold pixels: %0d", MIN_WHITE_PIXELS);
        $display("  Max allowed threshold pixels: %0d", MAX_WHITE_PIXELS);
    endtask
    
    // Task: Test zebra crossing detection
    task automatic test_zebra_detection();
        int timeout_counter;
        
        $display("\n==========================================================");
        $display("TEST 1: Zebra Crossing Detection with Real Images");
        $display("==========================================================");
        $display("Time: %0t - Starting detection test", $time);
        
        // Provide white pixel counts
        @(posedge clk);
        num_white_edge_pixels = white_edge_count;
        num_white_threshold_pixels = white_threshold_count;
        white_count_valid = 1;
        @(posedge clk);
        white_count_valid = 0;
        
        // Wait for criteria 1 and 2 to be evaluated
        repeat(5) @(posedge clk);
        
        $display("\nCriteria Evaluation (Pixel Counts):");
        $display("  1. Threshold pixels in range: %s (%0d pixels)", 
                 num_threshold_pixels_fulfilled ? "PASS" : "FAIL", 
                 white_threshold_count);
        $display("  2. Sufficient edge pixels: %s (%0d pixels)", 
                 num_edge_pixels_fulfilled ? "PASS" : "FAIL", 
                 white_edge_count);
        
        // Trigger edge analysis
        @(posedge clk);
        valid_to_read = 1;
        
        $display("\nTime: %0t - Starting edge connectivity analysis", $time);
        $display("  Total edges to process: %0d", total_edges);
        
        // Wait for processing to complete with timeout
        timeout_counter = 0;
        while (capture_trigger != 1'b1 && timeout_counter < 500000) begin
            @(posedge clk);
            timeout_counter++;
            
            // Show progress every 50k cycles
            if (timeout_counter % 50000 == 0) begin
                $display("  Processing... (cycle %0d)", timeout_counter);
            end
        end
        
        if (timeout_counter >= 500000) begin
            $error("Timeout waiting for detection to complete");
            $finish;
        end else begin
            $display("\nTime: %0t - Detection complete! (took %0d cycles)", $time, timeout_counter);
        end
        
        // Read final results
        @(posedge clk);
        @(posedge clk);
        
        $display("\nFinal Detection Results:");
        $display("  3. Connected edge instances: %s (detected: %0d, min: %0d)", 
                 num_connected_edge_instances_fulfilled ? "PASS" : "FAIL",
                 dut.num_connected_components,
                 MIN_CONNECTED_EDGE_INSTANCES);
        $display("  4. Lowest edge position: %s (y=%0d, min y=%0d)", 
                 lowest_edge_position_fulfilled ? "PASS" : "FAIL",
                 dut.max_y,
                 MIN_LOWEST_EDGE_Y);
        
        // Overall detection result
        if (num_threshold_pixels_fulfilled && 
            num_edge_pixels_fulfilled && 
            num_connected_edge_instances_fulfilled && 
            lowest_edge_position_fulfilled) begin
            $display("\n*** ZEBRA CROSSING DETECTED! ***");
        end else begin
            $display("\n*** NO ZEBRA CROSSING DETECTED ***");
        end
        
        // Reset for next test
        valid_to_read = 0;
        repeat(5) @(posedge clk);
    endtask
    
    // Task: Test with insufficient edges
    task automatic test_insufficient_edges();
        $display("\n==========================================================");
        $display("TEST 2: Insufficient Edge Pixels");
        $display("==========================================================");
        $display("Time: %0t - Testing with low edge count", $time);
        
        // Override edge count to be below threshold
        @(posedge clk);
        num_white_edge_pixels = MIN_EDGE_PIXELS / 2;  // Half of minimum
        num_white_threshold_pixels = white_threshold_count;
        white_count_valid = 1;
        @(posedge clk);
        white_count_valid = 0;
        
        repeat(5) @(posedge clk);
        
        $display("  Edge pixels: %0d (min: %0d)", MIN_EDGE_PIXELS / 2, MIN_EDGE_PIXELS);
        $display("  Result: %s", num_edge_pixels_fulfilled ? "PASS (unexpected)" : "FAIL (expected)");
        
        if (!num_edge_pixels_fulfilled) begin
            $display("  ✓ Correctly rejected due to insufficient edges");
        end else begin
            $warning("  ✗ Should have failed edge pixel criterion");
        end
        
        repeat(5) @(posedge clk);
    endtask
    
    // Task: Test with edges in wrong position
    task automatic test_wrong_position();
        int modified_edge_count;
        int timeout_counter;
        
        $display("\n==========================================================");
        $display("TEST 3: Edges in Wrong Position (Top of Image)");
        $display("==========================================================");
        $display("Time: %0t - Testing with edges only in top area", $time);
        
        // Modify edge list to only include edges from top 1/5 of image
        modified_edge_count = 0;
        for (int i = 0; i < total_edges; i++) begin
            if (edge_list[i].y < IMG_HEIGHT / 5) begin
                edge_list[modified_edge_count] = edge_list[i];
                modified_edge_count++;
            end
        end
        
        $display("  Modified edge count (top area only): %0d", modified_edge_count);
        num_edges = modified_edge_count;
        
        // Provide counts
        @(posedge clk);
        num_white_edge_pixels = white_edge_count;
        num_white_threshold_pixels = white_threshold_count;
        white_count_valid = 1;
        @(posedge clk);
        white_count_valid = 0;
        
        repeat(5) @(posedge clk);
        
        // Trigger detection
        @(posedge clk);
        valid_to_read = 1;
        
        // Wait for completion with timeout
        timeout_counter = 0;
        while (capture_trigger != 1'b1 && timeout_counter < 500000) begin
            @(posedge clk);
            timeout_counter++;
        end
        
        if (timeout_counter >= 500000) begin
            $error("Timeout waiting for detection to complete");
            $finish;
        end
        
        @(posedge clk);
        @(posedge clk);
        
        $display("  Lowest edge Y position: %0d (min: %0d)", dut.max_y, MIN_LOWEST_EDGE_Y);
        $display("  Result: %s", lowest_edge_position_fulfilled ? "PASS (unexpected)" : "FAIL (expected)");
        
        if (!lowest_edge_position_fulfilled) begin
            $display("  ✓ Correctly rejected due to wrong edge position");
        end else begin
            $warning("  ✗ Should have failed position criterion");
        end
        
        // Restore original edge list
        build_edge_list();
        valid_to_read = 0;
        repeat(5) @(posedge clk);
    endtask
    
    // Task: Test with too few white pixels
    task automatic test_insufficient_white_pixels();
        $display("\n==========================================================");
        $display("TEST 4: Insufficient White Threshold Pixels");
        $display("==========================================================");
        $display("Time: %0t - Testing with low threshold pixel count", $time);
        
        // Provide low white pixel count
        @(posedge clk);
        num_white_edge_pixels = white_edge_count;
        num_white_threshold_pixels = MIN_WHITE_PIXELS / 2;  // Half of minimum
        white_count_valid = 1;
        @(posedge clk);
        white_count_valid = 0;
        
        repeat(5) @(posedge clk);
        
        $display("  Threshold pixels: %0d (min: %0d)", MIN_WHITE_PIXELS / 2, MIN_WHITE_PIXELS);
        $display("  Result: %s", num_threshold_pixels_fulfilled ? "PASS (unexpected)" : "FAIL (expected)");
        
        if (!num_threshold_pixels_fulfilled) begin
            $display("  ✓ Correctly rejected due to insufficient white pixels");
        end else begin
            $warning("  ✗ Should have failed threshold pixel criterion");
        end
        
        repeat(5) @(posedge clk);
    endtask
    
    // Task: Save detection results to file
    task automatic save_results();
        int fd;
        
        $display("\n--- Saving Results ---");
        $display("Time: %0t - Writing to %s", $time, RESULTS_FILE);
        
        fd = $fopen(RESULTS_FILE, "w");
        if (fd == 0) begin
            $error("Cannot open output file: %s", RESULTS_FILE);
            return;
        end
        
        $fwrite(fd, "Zebra Crossing Detection Results\n");
        $fwrite(fd, "=================================\n\n");
        
        $fwrite(fd, "Image Information:\n");
        $fwrite(fd, "  Resolution: %0dx%0d\n", IMG_WIDTH, IMG_HEIGHT);
        $fwrite(fd, "  Total edges detected: %0d\n", total_edges);
        $fwrite(fd, "  White edge pixels: %0d\n", white_edge_count);
        $fwrite(fd, "  White threshold pixels: %0d\n\n", white_threshold_count);
        
        $fwrite(fd, "Detection Parameters:\n");
        $fwrite(fd, "  Min white pixels: %0d\n", MIN_WHITE_PIXELS);
        $fwrite(fd, "  Max white pixels: %0d\n", MAX_WHITE_PIXELS);
        $fwrite(fd, "  Min edge pixels: %0d\n", MIN_EDGE_PIXELS);
        $fwrite(fd, "  Min connected edge pixels: %0d\n", MIN_CONNECTED_EDGE_PIXELS);
        $fwrite(fd, "  Min connected instances: %0d\n", MIN_CONNECTED_EDGE_INSTANCES);
        $fwrite(fd, "  Min lowest edge Y: %0d\n\n", MIN_LOWEST_EDGE_Y);
        
        $fwrite(fd, "Detection Criteria:\n");
        $fwrite(fd, "  1. Threshold pixels in range: %s\n", 
                num_threshold_pixels_fulfilled ? "PASS" : "FAIL");
        $fwrite(fd, "  2. Sufficient edge pixels: %s\n", 
                num_edge_pixels_fulfilled ? "PASS" : "FAIL");
        $fwrite(fd, "  3. Connected edge instances: %s\n", 
                num_connected_edge_instances_fulfilled ? "PASS" : "FAIL");
        $fwrite(fd, "  4. Lowest edge position: %s\n\n", 
                lowest_edge_position_fulfilled ? "PASS" : "FAIL");
        
        if (num_threshold_pixels_fulfilled && 
            num_edge_pixels_fulfilled && 
            num_connected_edge_instances_fulfilled && 
            lowest_edge_position_fulfilled) begin
            $fwrite(fd, "FINAL RESULT: ZEBRA CROSSING DETECTED\n");
        end else begin
            $fwrite(fd, "FINAL RESULT: NO ZEBRA CROSSING DETECTED\n");
        end
        
        $fclose(fd);
        $display("Time: %0t - Results saved to %s", $time, RESULTS_FILE);
    endtask
    
    // Waveform dump
    initial begin
        $dumpfile("zebra_crossing_detector_tb.vcd");
        $dumpvars(0, zebra_crossing_detector_tb);
    end

endmodule