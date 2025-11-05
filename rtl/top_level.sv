module top_level (
	input  logic            CLOCK_50,
	input  logic    [9:0]   SW,          // SW0=start, SW1=obstacle, SW2=zebra, SW3=path_clear
	input  logic    [3:0]   KEY,         // KEY1=reset (active-low), KEY0=estop (active-low)
	inout           [35:0]  GPIO,        // GPIO[31] = UART TX to UGV02 RX
	
	output          [6:0]   HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7,
	output logic    [17:0]  LEDR,
	output          [7:0]   LEDG,
	
	output  logic           I2C_SCLK,
	inout                   I2C_SDAT,
	input                   AUD_ADCDAT,
	input                   AUD_BCLK,
	output  logic           AUD_XCK,
	input                   AUD_ADCLRCK,

	// camera inputs and outputs
	input  	logic		    OV7670_PCLK,
	input 	logic		    OV7670_VSYNC,
	input  	logic		    OV7670_HREF,
	input  	logic [7:0]	    OV7670_DATA,
	output 	logic		    OV7670_XCLK,
	output 	logic		    OV7670_SIOC,
	output 	logic		    OV7670_PWDN,
	output 	logic		    OV7670_RESET,
	inout  	wire		    OV7670_SIOD,
	
	// vga inputs and outputs
	output logic            VGA_HS,
	output logic		    VGA_VS,
	output logic [7:0]      VGA_R,
	output logic [7:0]      VGA_G,
	output logic [7:0]      VGA_B,
	output logic            VGA_BLANK_N,
	output logic            VGA_SYNC_N,
	output logic            VGA_CLK
	 
);
    // reset KEY[1]
    logic rst_n; 
    assign rst_n = KEY[0];

    logic tick_20hz;
    tick_gen #(
        .CLK_HZ(50_000_000), 
        .TICK_HZ(20)) 
    u_tick(
        .clk(CLOCK_50), 
        .rst_n(rst_n), 
        .tick(tick_20hz)
    );

    // =================== Command bus (3 bits) ===================
    logic [2:0] cmd_sel;

    logic stop_front_raw;
    logic stop_back_raw;


    logic whistle_detected, beep_detected;
    assign LEDG[7] = whistle_detected;

    top_level_proximity u_prox (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .GPIO(GPIO),        // shares the same header pins you used
        .LEDR(LEDR[17:15]), 
        .rst_n(rst_n),
        .tick_20hz(tick_20hz),
        .stop_front_2s(stop_front_raw),
        .stop_back_1s(stop_back_raw)
    );

    microphone_top_level #(
        .DE1_SOC(0)                 // DE2-115
    ) u_microphone_top_level (
        // clocks & keys
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .reset(~rst_n),

        // I2C for WM8731 (use these on DE2-115)
        .I2C_SCLK(I2C_SCLK),
        .I2C_SDAT(I2C_SDAT),

        // Unused from DE1
        .FPGA_I2C_SCLK(),
        .FPGA_I2C_SDAT(),

        // Audio codec I2S/clock
        .AUD_ADCDAT(AUD_ADCDAT),
        .AUD_BCLK(AUD_BCLK),
        .AUD_XCK(AUD_XCK),
        .AUD_ADCLRCK(AUD_ADCLRCK),

        // Detection outputs
        .whistle_detected(whistle_detected),
        .beep_detected(beep_detected),

        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7)
    );
        
    logic zebra_crossing_stop;

    top_level_vision u_vision (
        // board-level signals
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .rst_n(rst_n),

        // determine what to show on vga output
        .show_original(SW[0]),
        .show_grayscale(SW[1]),
        .show_edge(SW[2]),
        .show_threshold(SW[3]),

        // camera connections
        .OV7670_PCLK(OV7670_PCLK),
        .OV7670_VSYNC(OV7670_VSYNC),
        .OV7670_HREF(OV7670_HREF),
        .OV7670_DATA(OV7670_DATA),
        .OV7670_XCLK(OV7670_XCLK),
        .OV7670_SIOC(OV7670_SIOC),
        .OV7670_SIOD(OV7670_SIOD),
        .OV7670_PWDN(OV7670_PWDN),
        .OV7670_RESET(OV7670_RESET),

        // VGA outputs
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK),

        // output signal to FSM - tell it to stop
        .zebra_crossing_stop(zebra_crossing_stop)
    );

    assign LEDR[10] = zebra_crossing_stop;

    guide_fsm #(
        .CLK_HZ(50_000_000),
        .TICK_HZ(20),
        .BACK_MS(2000),
        .R1_MS(3000),
        .L1_MS(800),   // small left
        .COAST_MS(1800),  // straight
        .L2_MS(5000),   // continue left
        .R2_MS(3400),
        .ZEBRA_MS(3000)
    ) u_fsm (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .start_whistle(whistle_detected),
        .obstacle_stop(stop_front_raw),   
        .zebra_pattern_stop(zebra_crossing_stop),    
        .person_far_away_stop(stop_back_raw), 
        .tick_20hz(tick_20hz),
        .cmd_sel(cmd_sel)         // 3-bit command bus
    );

    // =================== JSON burst + UART (unchanged except 3-bit cmd_sel) ===================
    logic       tx_valid, tx_ready;
    logic [7:0] byte_to_send;

    json_burst #(
        .TICK_HZ(20)
    ) u_burst (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .tick_20hz(tick_20hz),
        .cmd_sel(cmd_sel),        // 3 bits now: STOP, FWD, ARC_L, ARC_R, REV
        .tx_valid(tx_valid),
        .tx_ready(tx_ready),
        .byte_to_send (byte_to_send)
    );

    uart_tx #(
        .CLKS_PER_BIT(50_000_000/115200),
        .BITS_N(8),
        .PARITY_TYPE(0)
    ) u_uart (
        .clk(CLOCK_50),
        .rst(1'b0),               // keep deasserted (as before)
        .data_tx(byte_to_send),
        .valid(tx_valid),
        .ready(tx_ready),
        .uart_out(GPIO[31])
    );

    // =================== (Optional) LEDs ===================
    localparam logic [2:0] CMD_STOP=3'd0, CMD_FWD=3'd1, CMD_ARC_L=3'd2, CMD_ARC_R=3'd3, CMD_REV=3'd4;
    assign LEDR[6] = (cmd_sel == CMD_STOP);
    assign LEDR[7] = (cmd_sel == CMD_FWD);
    assign LEDR[8] = (cmd_sel == CMD_ARC_L) | (cmd_sel == CMD_ARC_R);
    assign LEDR[9] = (cmd_sel == CMD_REV);

    // Handshake/debug (as you had them)
    assign LEDR[4] = tx_valid;  // 1-clk pulses (invisible by eye)
    assign LEDR[5] = tx_ready;  // should dip during frames if observed on LA

    // Byte counter per burst (optional – helps you see 24/25/26/27)
    logic [7:0] sent_cnt;
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
    if (!rst_n)          sent_cnt <= 8'd0;
    else if (tick_20hz)  sent_cnt <= 8'd0;
    else if (tx_valid)   sent_cnt <= sent_cnt + 8'd1;
    end
    assign LEDR[3:0] = sent_cnt[3:0];
endmodule 
