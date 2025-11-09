`timescale 1ns/1ps

module top_level_vision_tb;

  // ================================================================
  // Parameters
  // ================================================================
  localparam int N_COLS = 64;   // reduce for faster sim
  localparam int N_ROWS = 48;
  localparam int TOTAL_PIXELS = N_COLS * N_ROWS;

  // ================================================================
  // DUT I/O declarations
  // ================================================================
  logic CLOCK_50;
  logic [3:0] KEY;
  logic [17:0] SW;
  logic [17:0] LEDR;

  // Camera I/O
  logic OV7670_PCLK;
  logic OV7670_VSYNC;
  logic OV7670_HREF;
  logic [7:0] OV7670_DATA;
  logic OV7670_SIOC;
  tri   OV7670_SIOD;
  logic OV7670_PWDN;
  logic OV7670_RESET;
  logic OV7670_XCLK;

  // VGA I/O
  logic VGA_HS, VGA_VS;
  logic [7:0] VGA_R, VGA_G, VGA_B;
  logic VGA_BLANK_N, VGA_SYNC_N, VGA_CLK;
  logic zebra_crossing_stop;

  // ================================================================
  // Instantiate DUT
  // ================================================================
  top_level_vision DUT (
    .CLOCK_50(CLOCK_50),
    .KEY(KEY),
    .SW(SW),
    .LEDR(LEDR),
    .OV7670_PCLK(OV7670_PCLK),
    .OV7670_XCLK(OV7670_XCLK),
    .OV7670_VSYNC(OV7670_VSYNC),
    .OV7670_HREF(OV7670_HREF),
    .OV7670_DATA(OV7670_DATA),
    .OV7670_SIOC(OV7670_SIOC),
    .OV7670_SIOD(OV7670_SIOD),
    .OV7670_PWDN(OV7670_PWDN),
    .OV7670_RESET(OV7670_RESET),
    .VGA_HS(VGA_HS),
    .VGA_VS(VGA_VS),
    .VGA_R(VGA_R),
    .VGA_G(VGA_G),
    .VGA_B(VGA_B),
    .VGA_BLANK_N(VGA_BLANK_N),
    .VGA_SYNC_N(VGA_SYNC_N),
    .VGA_CLK(VGA_CLK),
    .zebra_crossing_stop(zebra_crossing_stop)
  );

  // ================================================================
  // Clock generation
  // ================================================================
  initial CLOCK_50 = 0;
  always #10 CLOCK_50 = ~CLOCK_50;    // 50 MHz board clock

  initial OV7670_PCLK = 0;
  always #10 OV7670_PCLK = ~OV7670_PCLK;  // simulate 50 MHz camera pixel clock

  // ================================================================
  // Reset and key setup
  // ================================================================
  initial begin
    KEY = 4'b1111; // all keys inactive
    SW  = 0;
    #100;
    KEY[0] = 0;  // assert reset
    #200;
    KEY[0] = 1;  // release reset
  end

	  // ================================================================
	// Camera stimulus (fake image pattern)
	// ================================================================
	logic [7:0] image [0:TOTAL_PIXELS-1];

	initial begin
	  // preload pattern
	  $readmemh("rainbow_small.hex", image);
	  $display("Image loaded, first few pixels: %h %h %h", image[0], image[1], image[2]);

	  OV7670_VSYNC = 1;  // hold high initially (no frame yet)
	  OV7670_HREF  = 0;
	  OV7670_DATA  = 0;

	  // Wait for reset release
	  wait (KEY[0] == 1);

	  // small delay for PLL lock
	  #2000;

	  // --- Frame start ---
	  OV7670_VSYNC = 0;  // drop VSYNC = start of frame
	  repeat (5) @(posedge OV7670_PCLK);

	  // Stream image pixels row by row
	  for (int row = 0; row < N_ROWS; row++) begin
		 OV7670_HREF = 1;
		 for (int col = 0; col < N_COLS; col++) begin
			OV7670_DATA = image[row * N_COLS + col];
			@(posedge OV7670_PCLK);
		 end
		 OV7670_HREF = 0;
		 // short blanking interval between rows
		 repeat (10) @(posedge OV7670_PCLK);
	  end

	  // --- Frame end ---
	  repeat (20) @(posedge OV7670_PCLK);
	  OV7670_VSYNC = 1;
	  repeat (4) @(posedge OV7670_PCLK);
	  OV7670_VSYNC = 0;

	  $display("[%0t] Completed one frame stimulus.", $time);
	end


  // ================================================================
  // Monitors
  // ================================================================
  initial begin
    $display("==== top_level_vision_tb Simulation Start ====");
    $monitor("[%0t] VSYNC=%b HREF=%b DATA=%h WREN=%b ADDR=%0d VGA_READY=%b STOP=%b",
             $time,
             OV7670_VSYNC, OV7670_HREF, OV7670_DATA,
             DUT.u_image_buffer.wren,
             DUT.u_image_buffer.wraddress,
             DUT.u_vga_driver.ready,
             zebra_crossing_stop);
  end

  // ================================================================
  // Simulation end
  // ================================================================
  initial begin
    #20_000_000;
    $display("[%0t] Simulation finished", $time);
    $stop;
  end

endmodule
