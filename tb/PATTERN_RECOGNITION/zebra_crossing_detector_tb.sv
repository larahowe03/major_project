module zebra_crossing_detector_tb;

    parameter IMG_WIDTH = 320;
    parameter IMG_HEIGHT = 240;
    parameter W = 8;
    parameter SCAN_STEP = 4;
    
    logic clk;
    logic rst_n;
    
    logic x_valid;
    logic x_ready;
    logic [W-1:0] x_data;
    
    logic y_valid;
    logic y_ready;
    logic [W-1:0] y_data;
    
    logic bbox_valid;
    logic [$clog2(IMG_WIDTH)-1:0] bbox_x_min;
    logic [$clog2(IMG_WIDTH)-1:0] bbox_x_max;
    logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_min;
    logic [$clog2(IMG_HEIGHT)-1:0] bbox_y_max;
    logic zebra_detected;
    logic [$clog2(IMG_WIDTH)-1:0] columns_detected_count;
    
    // DUT instantiation
    zebra_crossing_detector #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .W(W),
        .WHITE_THRESHOLD(8'd180),
        .BLACK_THRESHOLD(8'd75),
        .MIN_STRIPE_HEIGHT(4),
        .MIN_ALTERNATIONS(4),
        .MIN_COLUMNS_DETECTED(20),
        .SCAN_STEP(SCAN_STEP)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .x_valid(x_valid),
        .x_ready(x_ready),
        .x_data(x_data),
        .y_valid(y_valid),
        .y_ready(y_ready),
        .y_data(y_data),
        .bbox_valid(bbox_valid),
        .bbox_x_min(bbox_x_min),
        .bbox_x_max(bbox_x_max),
        .bbox_y_min(bbox_y_min),
        .bbox_y_max(bbox_y_max),
        .zebra_detected(zebra_detected),
        .columns_detected_count(columns_detected_count)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test image memory
    logic [W-1:0] test_image [0:IMG_HEIGHT-1][0:IMG_WIDTH-1];
    
    // Read image from MIF file
    task read_mif(input string filename);
        integer file, status, x, y, addr, value;
        string line;
        
        $display("\n[%0t] Reading MIF file: %s", $time, filename);
        
        // Initialize to black
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                test_image[y][x] = 8'd0;
            end
        end
        
        file = $fopen(filename, "r");
        if (file == 0) begin
            $display("ERROR: Could not open file %s", filename);
            $display("Generating synthetic pattern instead...");
            generate_zebra_pattern();
            return;
        end
        
        addr = 0;
        
        // Read file line by line
        while (!$feof(file)) begin
            status = $fgets(line, file);
            if (status == 0) break;
            
            // Skip comments and empty lines
            if (line[0] == "/" || line[0] == "-" || line[0] == " " || line[0] == "\n") begin
                continue;
            end
            
            // Try to parse as hex value
            if ($sscanf(line, "%h", value) == 1) begin
                if (addr < IMG_WIDTH * IMG_HEIGHT) begin
                    y = addr / IMG_WIDTH;
                    x = addr % IMG_WIDTH;
                    test_image[y][x] = value[W-1:0];
                    addr++;
                end
            end
        end
        
        $fclose(file);
        $display("[%0t] Successfully loaded %0d pixels from MIF", $time, addr);
        
        if (addr != IMG_WIDTH * IMG_HEIGHT) begin
            $display("WARNING: Expected %0d pixels, got %0d", IMG_WIDTH * IMG_HEIGHT, addr);
        end
    endtask
    
    // Generate synthetic zebra crossing pattern (fallback)
    task generate_zebra_pattern();
        integer x, y;
        integer zebra_x_start, zebra_x_end;
        integer zebra_y_start, zebra_y_end;
        integer stripe_width;
        integer stripe_num;
        
        // Initialize to gray background
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                test_image[y][x] = 8'd100; // Gray background
            end
        end
        
        // Draw zebra crossing in the center
        zebra_x_start = 80;
        zebra_x_end = 240;
        zebra_y_start = 80;
        zebra_y_end = 160;
        stripe_width = 10;
        
        $display("Generating zebra crossing:");
        $display("  X: %0d to %0d", zebra_x_start, zebra_x_end);
        $display("  Y: %0d to %0d", zebra_y_start, zebra_y_end);
        
        // Draw alternating stripes
        for (y = zebra_y_start; y < zebra_y_end; y++) begin
            stripe_num = (y - zebra_y_start) / stripe_width;
            for (x = zebra_x_start; x < zebra_x_end; x++) begin
                if (stripe_num % 2 == 0) begin
                    test_image[y][x] = 8'd250; // White stripe
                end else begin
                    test_image[y][x] = 8'd20;  // Black stripe
                end
            end
        end
    endtask
    
    // Stream test image to DUT
    task stream_image();
        integer x, y;
        
        $display("\n[%0t] Starting image stream...", $time);
        
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                x_valid = 1'b1;
                x_data = test_image[y][x];
                
                // Wait for handshake
                @(posedge clk);
                while (!x_ready) begin
                    @(posedge clk);
                end
            end
        end
        
        x_valid = 1'b0;
        x_data = 8'd0;
        
        $display("[%0t] Image stream complete", $time);
    endtask
    
    // Monitor bounding box output
    always @(posedge clk) begin
        if (bbox_valid) begin
            $display("\n========================================");
            $display("BOUNDING BOX DETECTED!");
            $display("========================================");
            $display("Zebra Detected: %b", zebra_detected);
            $display("Columns Detected: %0d", columns_detected_count);
            $display("Bounding Box:");
            $display("  X: [%0d, %0d] (width: %0d)", bbox_x_min, bbox_x_max, bbox_x_max - bbox_x_min + 1);
            $display("  Y: [%0d, %0d] (height: %0d)", bbox_y_min, bbox_y_max, bbox_y_max - bbox_y_min + 1);
            $display("========================================\n");
        end
    end
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("Zebra Crossing Bounding Box Detector Test");
        $display("========================================");
        
        // Initialize
        rst_n = 0;
        x_valid = 0;
        x_data = 0;
        y_ready = 1;
        
        // Load test image from MIF
        // Try to read from MIF file, fall back to synthetic if not found
        read_mif("present.mif");
        
        // Reset
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        // Stream image
        stream_image();
        
        // Wait for processing
        repeat(100) @(posedge clk);
        
        // Test with second image if available
        $display("\n\n========================================");
        $display("Test 2: Second test image");
        $display("========================================");
        
        read_mif("not_present.mif");
        stream_image();
        repeat(100) @(posedge clk);
        
        $display("\n========================================");
        $display("Test Complete!");
        $display("========================================");
        $finish;
    end
    
    // Timeout
    initial begin
        #1000000;
        $display("ERROR: Timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("zebra_detector_bbox.vcd");
        $dumpvars(0, zebra_crossing_detector_tb);
    end

endmodule