`timescale 1ns / 1ps

module sparse_edge_storage_tb;

    // Parameters
    localparam IMG_WIDTH = 640;
    localparam IMG_HEIGHT = 480;
    localparam MAX_EDGES = 2048;
    localparam string IMG_FILE = "blur_edge_image.mif";
    localparam string OUTPUT_FILE = "detected_edges.txt";
    
    // Clock and reset
    logic clk;
    logic rst_n;
    
    // Write port signals
    logic write_valid;
    logic [7:0] write_data;
    logic [$clog2(IMG_WIDTH)-1:0] write_x;
    logic [$clog2(IMG_HEIGHT)-1:0] write_y;
    
    // Capture control signals
    logic capture_trigger;
    logic frame_complete;
    logic capturing;
    logic valid_to_read;
    
    // Read port signals
    logic [$clog2(MAX_EDGES)-1:0] read_idx;
    logic [$clog2(IMG_WIDTH)-1:0] edge_x;
    logic [$clog2(IMG_HEIGHT)-1:0] edge_y;
    logic edge_valid;
    
    // Statistics
    logic [$clog2(MAX_EDGES)-1:0] num_edges;
    logic buffer_overflow;
    
    // Test data storage
    typedef struct {
        logic [$clog2(IMG_WIDTH)-1:0] x;
        logic [$clog2(IMG_HEIGHT)-1:0] y;
    } edge_coord_t;
    
    edge_coord_t stored_edges [MAX_EDGES];
    int edge_count;
    
    // Image data from MIF file
    logic [7:0] image_data [IMG_HEIGHT-1:0][IMG_WIDTH-1:0];
    
    // Instantiate DUT
    sparse_edge_storage #(
        .IMG_WIDTH(IMG_WIDTH),
        .IMG_HEIGHT(IMG_HEIGHT),
        .MAX_EDGES(MAX_EDGES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .write_valid(write_valid),
        .write_data(write_data),
        .write_x(write_x),
        .write_y(write_y),
        .capture_trigger(capture_trigger),
        .frame_complete(frame_complete),
        .capturing(capturing),
        .valid_to_read(valid_to_read),
        .read_idx(read_idx),
        .edge_x(edge_x),
        .edge_y(edge_y),
        .edge_valid(edge_valid),
        .num_edges(num_edges),
        .buffer_overflow(buffer_overflow)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst_n = 0;
        write_valid = 0;
        write_data = 0;
        write_x = 0;
        write_y = 0;
        capture_trigger = 0;
        frame_complete = 0;
        read_idx = 0;
        edge_count = 0;
        
        // Reset
        repeat(10) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);
        
        $display("=== Sparse Edge Storage Testbench ===");
        $display("Time: %0t - Starting test", $time);
        
        // Load image from MIF file
        load_image_from_mif();
        
        // Test: Process image and store edges
        test_process_image();
        
        // Wait for valid_to_read signal
        wait_for_valid_to_read();
        
        // Verify statistics
        verify_statistics();
        
        // Save detected edges to file
        save_edges_to_file();
        
        // Test: Multiple capture cycles
        test_multiple_captures();
        
        $display("\n=== Test Summary ===");
        $display("Time: %0t - All tests completed successfully!", $time);
        $finish;
    end
    
    // Task: Load image from MIF file
    task automatic load_image_from_mif();
        integer fd, x, y, pixel, addr, data;
        integer pixels_loaded;
        string line;
        
        $display("\n--- Loading Image from MIF File ---");
        $display("Time: %0t - Reading from %s", $time, IMG_FILE);
        
        fd = $fopen(IMG_FILE, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", IMG_FILE);
            $finish;
        end
        
        // Skip header until CONTENT
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 6) == "CONTENT") break;
        end
        
        // Skip BEGIN
        $fgets(line, fd);
        
        pixels_loaded = 0;
        y = 0;
        x = 0;
        
        // Read data lines
        while (!$feof(fd)) begin
            if ($fgets(line, fd) == 0) continue;
            if (line.substr(0, 2) == "END") break;
            
            if ($sscanf(line, "%h : %h", addr, data) == 2) begin
                image_data[y][x] = data[7:0];
                pixels_loaded++;
                
                x++;
                if (x >= IMG_WIDTH) begin
                    x = 0;
                    y++;
                end
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - Image loaded: %0d pixels", $time, pixels_loaded);
    endtask

    // Task: Process image and stream to DUT
    task automatic test_process_image();
        int x, y;
        int edge_pixel_count;
        
        $display("\n--- Processing Image and Storing Edges ---");
        $display("Time: %0t - Starting edge capture", $time);
        
        edge_pixel_count = 0;
        
        // Assert capture trigger to start capturing
        @(posedge clk);
        capture_trigger = 1;
        @(posedge clk);
        capture_trigger = 0;
        
        // Wait for capturing signal to go high
        wait(capturing == 1'b1);
        $display("Time: %0t - Capture started (capturing signal high)", $time);
        
        // Stream all pixels from the loaded image
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                write_valid = 1;
                write_data = image_data[y][x];
                write_x = x;
                write_y = y;
                
                // Count edge pixels for verification
                if (write_data == 8'd255) begin
                    edge_pixel_count++;
                    if (edge_pixel_count <= 10) begin
                        $display("Time: %0t - Edge pixel detected at (%0d, %0d)", $time, x, y);
                    end
                end
                
                @(posedge clk);
            end
        end
        
        // Deassert write_valid
        write_valid = 0;
        write_data = 0;
        @(posedge clk);
        
        $display("Time: %0t - All pixels streamed (%0d edge pixels detected)", $time, edge_pixel_count);
        
        // Assert frame_complete to signal end of frame
        frame_complete = 1;
        @(posedge clk);
        frame_complete = 0;
        @(posedge clk);
        
        $display("Time: %0t - Frame complete signal sent", $time);
        
        // Store edge count for later verification
        edge_count = edge_pixel_count;
    endtask

    // Task: Wait for valid_to_read signal
    task automatic wait_for_valid_to_read();
        int timeout_cycles;
        
        $display("\n--- Waiting for Buffer Copy ---");
        $display("Time: %0t - Waiting for valid_to_read signal", $time);
        
        timeout_cycles = 0;
        while (valid_to_read != 1'b1 && timeout_cycles < 10000) begin
            @(posedge clk);
            timeout_cycles++;
        end
        
        if (valid_to_read) begin
            $display("Time: %0t - Valid to read signal asserted (after %0d cycles)", $time, timeout_cycles);
        end else begin
            $error("Time: %0t - Timeout waiting for valid_to_read signal", $time);
            $finish;
        end
    endtask

    // Task: Verify statistics
    task automatic verify_statistics();
        $display("\n--- Verifying Statistics ---");
        $display("Time: %0t - Number of edges stored: %0d", $time, num_edges);
        $display("Time: %0t - Buffer overflow flag: %0b", $time, buffer_overflow);
        
        if (buffer_overflow) begin
            $warning("Buffer overflow occurred - image has more than %0d edges", MAX_EDGES);
        end
        
        // Check if edge count matches (accounting for overflow)
        if (edge_count <= MAX_EDGES) begin
            if (num_edges == edge_count) begin
                $display("Time: %0t - ✓ Edge count matches expected value", $time);
            end else begin
                $warning("Time: %0t - Edge count mismatch: expected %0d, got %0d", 
                         $time, edge_count, num_edges);
            end
        end else begin
            if (num_edges == MAX_EDGES) begin
                $display("Time: %0t - ✓ Edge count saturated at MAX_EDGES as expected", $time);
            end else begin
                $warning("Time: %0t - Expected saturation at %0d, got %0d", 
                         $time, MAX_EDGES, num_edges);
            end
        end
    endtask
    
    // Task: Read and save edges to file
    task automatic save_edges_to_file();
        int fd, i;
        
        $display("\n--- Saving Detected Edges ---");
        $display("Time: %0t - Writing to %s", $time, OUTPUT_FILE);
        
        fd = $fopen(OUTPUT_FILE, "w");
        if (fd == 0) begin
            $error("Cannot open output file: %s", OUTPUT_FILE);
            return;
        end
        
        // Write header
        $fwrite(fd, "# Detected Edges\n");
        $fwrite(fd, "# Format: x y\n");
        $fwrite(fd, "# Total edges: %0d\n", num_edges);
        $fwrite(fd, "# Buffer overflow: %0b\n", buffer_overflow);
        $fwrite(fd, "\n");
        
        // Read back all edges from DUT and save
        for (i = 0; i < num_edges; i++) begin
            read_idx = i;
            @(posedge clk);
            @(posedge clk); // Extra cycle for read latency
            
            if (edge_valid) begin
                $fwrite(fd, "%0d %0d\n", edge_x, edge_y);
                if (i < 10 || i >= num_edges - 5) begin
                    $display("Time: %0t - Edge %0d: (%0d, %0d)", $time, i, edge_x, edge_y);
                end else if (i == 10) begin
                    $display("Time: %0t - ... (showing first 10 and last 5 edges)", $time);
                end
            end else begin
                $warning("Edge %0d: invalid read", i);
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - All edges saved to %s", $time, OUTPUT_FILE);
    endtask
    
    // Task: Test multiple capture cycles
    task automatic test_multiple_captures();
        int x, y, test_edges;
        
        $display("\n--- Testing Multiple Capture Cycles ---");
        $display("Time: %0t - Starting second capture cycle", $time);
        
        // Trigger second capture
        @(posedge clk);
        capture_trigger = 1;
        @(posedge clk);
        capture_trigger = 0;
        
        // Wait for capturing signal
        wait(capturing == 1'b1);
        $display("Time: %0t - Second capture started", $time);
        
        // Stream a simple test pattern (vertical line)
        test_edges = 0;
        for (y = 0; y < IMG_HEIGHT; y++) begin
            for (x = 0; x < IMG_WIDTH; x++) begin
                write_valid = 1;
                // Create a vertical line at x=320
                if (x == 320) begin
                    write_data = 8'd255;
                    test_edges++;
                end else begin
                    write_data = 8'd0;
                end
                write_x = x;
                write_y = y;
                @(posedge clk);
            end
        end
        
        write_valid = 0;
        @(posedge clk);
        
        // Signal frame complete
        frame_complete = 1;
        @(posedge clk);
        frame_complete = 0;
        @(posedge clk);
        
        // Wait for valid_to_read
        while (valid_to_read != 1'b1) begin
            @(posedge clk);
        end
        
        $display("Time: %0t - Second capture complete", $time);
        $display("Time: %0t - Expected edges: %0d, Stored edges: %0d", 
                 $time, test_edges, num_edges);
        
        if (num_edges == test_edges) begin
            $display("Time: %0t - ✓ Second capture successful", $time);
        end else begin
            $warning("Time: %0t - Second capture edge count mismatch", $time);
        end
    endtask
    
    // Dump waveforms
    initial begin
        $dumpfile("sparse_edge_storage_tb.vcd");
        $dumpvars(0, sparse_edge_storage_tb);
    end

endmodule