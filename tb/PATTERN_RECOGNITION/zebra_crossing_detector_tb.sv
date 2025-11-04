`timescale 1ns / 1ps

module zebra_crossing_detector_tb;

    // ========================================================================
    // Parameters
    // ========================================================================
    localparam IMG_WIDTH = 640;
    localparam IMG_HEIGHT = 480;
    localparam MAX_EDGES = 2048;
    localparam MIN_WHITE_PIXELS = 15360;
    localparam MAX_WHITE_PIXELS = 53760;
    localparam MIN_EDGE_PIXELS = 1000;
    localparam MIN_CONNECTED_EDGE_PIXELS = 20;
    localparam MIN_CONNECTED_EDGE_INSTANCES = 10;
    
    localparam CLK_PERIOD = 20; // 50 MHz
    
    // ========================================================================
    // DUT Signals
    // ========================================================================
    logic clk;
    logic rst_n;
    
    logic valid_to_read;
    
    logic [$clog2(MAX_EDGES)-1:0] edge_read_idx;
    logic [$clog2(IMG_WIDTH)-1:0] edge_x;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_y;
    logic edge_valid;
    logic [$clog2(MAX_EDGES)-1:0] num_edges;
    
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_edge_pixels;
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_white_threshold_pixels;
    logic white_count_valid;
    
    logic num_threshold_pixels_fulfilled;
    logic num_edge_pixels_fulfilled;
    logic num_connected_edge_instances_fulfilled;
    
    logic capture_trigger;
    
    logic [$clog2(IMG_WIDTH*IMG_HEIGHT)-1:0] num_connected_components;
    logic components_done;
    
    // ========================================================================
    // Test Data Storage
    // ========================================================================
    typedef struct {
        logic [$clog2(IMG_WIDTH)-1:0] x;
        logic [$clog2(IMG_HEIGHT)-1:0] y;
    } edge_coord_t;
    
    edge_coord_t edge_list [0:MAX_EDGES-1];
    int num_edges_loaded;
    
    logic [7:0] edge_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    logic [7:0] threshold_image [0:IMG_WIDTH*IMG_HEIGHT-1];
    
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
        .MAX_EDGES(MAX_EDGES),
        .MIN_WHITE_PIXELS(MIN_WHITE_PIXELS),
        .MAX_WHITE_PIXELS(MAX_WHITE_PIXELS),
        .MIN_EDGE_PIXELS(MIN_EDGE_PIXELS),
        .MIN_CONNECTED_EDGE_PIXELS(MIN_CONNECTED_EDGE_PIXELS),
        .MIN_CONNECTED_EDGE_INSTANCES(MIN_CONNECTED_EDGE_INSTANCES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_to_read(valid_to_read),
        .edge_read_idx(edge_read_idx),
        .edge_x(edge_x),
        .edge_y(edge_y),
        .edge_valid(edge_valid),
        .num_edges(num_edges_loaded),
        .num_white_edge_pixels(num_white_edge_pixels),
        .num_white_threshold_pixels(num_white_threshold_pixels),
        .white_count_valid(white_count_valid),
        .num_threshold_pixels_fulfilled(num_threshold_pixels_fulfilled),
        .num_edge_pixels_fulfilled(num_edge_pixels_fulfilled),
        .num_connected_edge_instances_fulfilled(num_connected_edge_instances_fulfilled),
        .capture_trigger(capture_trigger),
        .num_connected_components(num_connected_components),
        .components_done(components_done)
    );
    
    // ========================================================================
    // Edge List ROM - Provides edge coordinates on demand
    // ========================================================================
    logic [$clog2(IMG_WIDTH)-1:0] edge_x_rom;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_y_rom;
    logic edge_valid_rom;
    
    always_comb begin
        if (edge_read_idx < num_edges_loaded) begin
            edge_x_rom = edge_list[edge_read_idx].x;
            edge_y_rom = edge_list[edge_read_idx].y;
            edge_valid_rom = 1'b1;
        end else begin
            edge_x_rom = '0;
            edge_y_rom = '0;
            edge_valid_rom = 1'b0;
        end
    end
    
    // Add one cycle delay to simulate BRAM read latency
    always_ff @(posedge clk) begin
        edge_x <= edge_x_rom;
        edge_y <= edge_y_rom;
        edge_valid <= edge_valid_rom;
    end
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    initial begin
        $display("=== Zebra Crossing Detector Testbench ===\n");
        
        // Initialize
        rst_n = 0;
        valid_to_read = 0;
        num_edges_loaded = 0;
        
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("Time: %0t - Loading test data", $time);
        
        // Load test data from files
        load_edge_coordinates("detected_edges.txt");
        load_mif_image("edge_img.mif", edge_image);
        load_mif_image("thresholded_img.mif", threshold_image);
        
        // Calculate statistics from images
        calculate_white_pixel_counts();
        
        $display("\n--- Test Data Loaded ---");
        $display("  Edge coordinates loaded: %0d", num_edges_loaded);
        $display("  Edge image loaded: %0d x %0d", IMG_WIDTH, IMG_HEIGHT);
        $display("  Threshold image loaded: %0d x %0d", IMG_WIDTH, IMG_HEIGHT);
        
        // Trigger analysis
        $display("\nTime: %0t - Starting detector analysis", $time);
        valid_to_read = 1;
        @(posedge clk);
        valid_to_read = 0;
        
        // Wait for component analysis to complete
        wait(components_done == 1'b1);
        $display("Time: %0t - Component analysis complete", $time);
        
        // Display results
        display_results();
        
        repeat(10) @(posedge clk);
        $display("\nTime: %0t - Test completed", $time);
        $finish;
    end
    
    // ========================================================================
    // Load Edge Coordinates from Text File
    // ========================================================================
    task automatic load_edge_coordinates(input string filename);
        integer fd, status, x, y;
        integer count;
        
        $display("\nLoading edge coordinates from: %s", filename);
        
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", filename);
            $finish;
        end
        
        count = 0;
        
        // Skip header lines (starting with #)
        while (!$feof(fd)) begin
            if ($fscanf(fd, "%d %d", x, y) == 2) begin
                if (count < MAX_EDGES) begin
                    edge_list[count].x = x;
                    edge_list[count].y = y;
                    count++;
                    
                    if (count <= 10 || count % 100 == 0) begin
                        $display("  Edge %0d: (%0d, %0d)", count-1, x, y);
                    end
                end
            end
        end
        
        $fclose(fd);
        
        num_edges_loaded = count;
        $display("Successfully loaded %0d edges", num_edges_loaded);
        
        if (num_edges_loaded == 0) begin
            $error("No edges loaded from file!");
            $finish;
        end
    endtask
    
    // ========================================================================
    // Load MIF Image File
    // ========================================================================
    task automatic load_mif_image(input string filename, output logic [7:0] image_data [0:IMG_WIDTH*IMG_HEIGHT-1]);
        integer fd, status, addr, data, i;
        integer pixels_loaded;
        reg [200*8:1] line;
        
        $display("Loading MIF image from: %s", filename);
        
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", filename);
            return;
        end
        
        // Initialize image to 0
        for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i++) begin
            image_data[i] = 8'h00;
        end
        
        pixels_loaded = 0;
        
        // Parse MIF format: addr : data ;
        while (!$feof(fd)) begin
            status = $fscanf(fd, "%h : %h", addr, data);
            if (status == 2 && addr < IMG_WIDTH*IMG_HEIGHT) begin
                image_data[addr] = data[7:0];
                pixels_loaded++;
            end
        end
        
        $fclose(fd);
        $display("Successfully loaded %0d pixels", pixels_loaded);
    endtask
    
    // ========================================================================
    // Calculate White Pixel Counts
    // ========================================================================
    task automatic calculate_white_pixel_counts();
        integer i, white_edge_count, white_threshold_count;
        
        white_edge_count = 0;
        white_threshold_count = 0;
        
        // Count white pixels (255) in both images
        for (i = 0; i < IMG_WIDTH*IMG_HEIGHT; i++) begin
            if (edge_image[i] == 8'hFF) begin
                white_edge_count++;
            end
            if (threshold_image[i] == 8'hFF) begin
                white_threshold_count++;
            end
        end
        
        // Simulate the white_count_valid signal
        repeat(50) @(posedge clk);
        
        white_count_valid = 1;
        @(posedge clk);
        white_count_valid = 0;
        
        $display("\n--- White Pixel Statistics ---");
        $display("  Edge detection white pixels: %0d", white_edge_count);
        $display("  Threshold white pixels: %0d", white_threshold_count);
        $display("  Min threshold pixels: %0d", MIN_WHITE_PIXELS);
        $display("  Max threshold pixels: %0d", MAX_WHITE_PIXELS);
        $display("  Min edge pixels: %0d", MIN_EDGE_PIXELS);
    endtask
    
    // ========================================================================
    // Display Final Results
    // ========================================================================
    task automatic display_results();
        $display("\n=== DETECTION RESULTS ===");
        
        $display("\nCriteria Check:");
        $display("  [%s] Threshold pixels fulfilled (%0d pixels)", 
            num_threshold_pixels_fulfilled ? "✓" : "✗", 
            num_threshold_pixels_fulfilled);
        $display("  [%s] Edge pixels fulfilled (%0d pixels)", 
            num_edge_pixels_fulfilled ? "✓" : "✗", 
            num_edge_pixels_fulfilled);
        $display("  [%s] Connected components fulfilled (%0d components)", 
            num_connected_edge_instances_fulfilled ? "✓" : "✗", 
            num_connected_components);
        
        $display("\nComponent Analysis:");
        $display("  Number of connected components: %0d", num_connected_components);
        $display("  Minimum required: %0d", MIN_CONNECTED_EDGE_INSTANCES);
        $display("  Minimum pixels per component: %0d", MIN_CONNECTED_EDGE_PIXELS);
        
        $display("\nCapture Trigger: %s", capture_trigger ? "ACTIVE" : "INACTIVE");
        
        // Overall result
        if (num_threshold_pixels_fulfilled && num_edge_pixels_fulfilled && 
            num_connected_edge_instances_fulfilled) begin
            $display("\n✓ ZEBRA CROSSING DETECTED");
        end else begin
            $display("\n✗ ZEBRA CROSSING NOT DETECTED");
        end
    endtask
    
    // ========================================================================
    // Optional: Waveform Dump
    // ========================================================================
    initial begin
        $dumpfile("zebra_crossing_detector_tb.vcd");
        $dumpvars(0, zebra_crossing_detector_tb);
    end
    
    // ========================================================================
    // Timeout Watchdog
    // ========================================================================
    initial begin
        #(CLK_PERIOD * 100000); // 100k cycles timeout
        $error("Testbench timeout!");
        $finish;
    end

endmodule