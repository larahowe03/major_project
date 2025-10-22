// File digital_cam_impl1/top_level.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// cristinel ababei; Jan.29.2015; CopyLeft (CL);
// code name: "digital cam implementation #1";
// project done using Quartus II 13.1 and tested on DE2-115;
//
// this design basically connects a CMOS camera (OV7670 module) to
// DE2-115 board; video frames are picked up from camera, buffered
// on the FPGA (using embedded RAM), and displayed on the VGA monitor,
// which is also connected to the board; clock signals generated
// inside FPGA using ALTPLL's that take as input the board's 50MHz signal
// from on-board oscillator; 
//
// this whole project is an adaptation of Mike Field's original implementation 
// that can be found here:
// http://hamsterworks.co.nz/mediawiki/index.php/OV7670_camera
// no timescale needed

module top_level (
input wire CLOCK_50,
input wire [3:0] KEY,
output wire [8:0] LEDG,
output wire VGA_HS,
output wire VGA_VS,
output wire [7:0] VGA_R,
output wire [7:0] VGA_G,
output wire [7:0] VGA_B,
output wire VGA_BLANK_N,
output wire VGA_SYNC_N,
output wire VGA_CLK,
inout  wire [35:0] GPIO
);

wire ov7670_pclk; assign ov7670_pclk  = GPIO[21];
wire ov7670_xclk; assign GPIO[20]     = ov7670_xclk;
wire ov7670_vsync;assign ov7670_vsync = GPIO[23];
wire ov7670_href; assign ov7670_href  = GPIO[22];
wire [7:0] ov7670_data; assign ov7670_data  = GPIO[19:12];
wire ov7670_sioc; assign GPIO[25]     = ov7670_sioc;
wire ov7670_siod; assign GPIO[24]     = ov7670_siod;
wire ov7670_pwdn;
wire ov7670_reset;assign GPIO[11]     = ov7670_reset;

// DE2-115 board has an Altera Cyclone V E, which has ALTPLL's'
wire clk_50_camera;
wire clk_25_vga;
wire wren;
wire resend;
wire nBlank;
wire vSync;
wire [16:0] wraddress;
wire [11:0] wrdata;
wire [16:0] rdaddress;
wire [11:0] rddata;
wire [7:0] red; wire [7:0] green; wire [7:0] blue;
wire activeArea;

  assign VGA_R = red[7:0];
  assign VGA_G = green[7:0];
  assign VGA_B = blue[7:0];
  my_altpll Inst_vga_pll(
      .inclk0(CLOCK_50),
    .c0(clk_50_camera),
    .c1(clk_25_vga));

  // take the inverted push button because KEY0 on DE2-115 board generates
  // a signal 111000111; with 1 with not pressed and 0 when pressed/pushed;
  assign resend =  ~KEY[0];
  assign VGA_VS = vSync;
  assign VGA_BLANK_N = nBlank;
  VGA Inst_VGA(
      .CLK25(clk_25_vga),
    .clkout(VGA_CLK),
    .Hsync(VGA_HS),
    .Vsync(vSync),
    .Nblank(nBlank),
    .Nsync(VGA_SYNC_N),
    .activeArea(activeArea));

  ov7670_controller Inst_ov7670_controller(
      .clk(clk_50_camera),
    .resend(resend),
    .config_finished(LEDG[0]),
    .sioc(ov7670_sioc),
    .siod(ov7670_siod),
    .reset(ov7670_reset),
    .pwdn(ov7670_pwdn),
    .xclk(ov7670_xclk));

  ov7670_capture Inst_ov7670_capture(
      .pclk(ov7670_pclk),
    .vsync(ov7670_vsync),
    .href(ov7670_href),
    .d(ov7670_data),
    .addr(wraddress),
    .dout(wrdata),
    .we(wren));

  frame_buffer Inst_frame_buffer(
      .rdaddress(rdaddress),
    .rdclock(clk_25_vga),
    .q(rddata),
    .wrclock(ov7670_pclk),
    .wraddress(wraddress[16:0]),
    .data(wrdata),
    .wren(wren));

  RGB Inst_RGB(
      .Din(rddata),
    .Nblank(activeArea),
    .R(red),
    .G(green),
    .B(blue));

  Address_Generator Inst_Address_Generator(
      .CLK25(clk_25_vga),
    .enable(activeArea),
    .vsync(vSync),
    .address(rdaddress));


endmodule

