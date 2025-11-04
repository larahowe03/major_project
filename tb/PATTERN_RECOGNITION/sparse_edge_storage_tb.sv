`timescale 1ns / 1ps

module sparse_edge_storage_tb;

    // Parameters
    localparam IMG_WIDTH = 640;
    localparam IMG_HEIGHT = 480;
    localparam MAX_EDGES = 2048;
    localparam string IMG_FILE = "edge_img.mif";
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
        
        // Save detected edges to file
        save_edges_to_file();
        
        $display("Time: %0t - All tests completed", $time);
        $finish;
    end
    
    // Task: Load image from MIF file
    task automatic load_image_from_mif();
        int fd, x, y, pixel;
        string line;
        
        $display("\n--- Loading Image from MIF File ---");
        $display("Time: %0t - Reading from %s", $time, IMG_FILE);
        
        fd = $fopen(IMG_FILE, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", IMG_FILE);
            $finish;
        end
        
        // Simple MIF parser (format: pixel values as hex or decimal)
        y = 0;
        x = 0;
        
        while (!$feof(fd) && y < IMG_HEIGHT) begin
            if ($fscanf(fd, "%d", pixel) == 1) begin
                image_data[y][x] = pixel;
                
                x++;
                if (x >= IMG_WIDTH) begin
                    x = 0;
                    y++;
                end
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - Image loaded: %0d x %0d pixels", $time, IMG_WIDTH, IMG_HEIGHT);
    endtask
    
    // Task: Process image and detect edges
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
        $fwrite(fd, "\n");
        
        // Read back all edges from DUT and save
        for (i = 0; i < num_edges; i++) begin
            read_idx = i;
            @(posedge clk);
            
            if (edge_valid) begin
                $fwrite(fd, "%0d %0d\n", edge_x, edge_y);
                $display("Time: %0t - Edge %0d saved: (%0d, %0d)", $time, i, edge_x, edge_y);
            end else begin
                $warning("Edge %0d: invalid read", i);
            end
        end
        
        $fclose(fd);
        $display("Time: %0t - All edges saved to %s", $time, OUTPUT_FILE);
    endtask
    
    // Dump waveforms
    initial begin
        $dumpfile("sparse_edge_storage_tb.vcd");
        $dumpvars(0, sparse_edge_storage_tb);
    end

endmodule