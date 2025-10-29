module top_level (
    input CLOCK_50,
    input [3:0] KEYS,
    output [17:0] LEDR,
    output [7:0] LEDG,
    inout [35:0] GPIO,  // Entire GPIO_0 bus (bidirectional)
    
    // Mic
    output  logic        I2C_SCLK,
    inout                I2C_SDAT,
    input                AUD_ADCDAT,
    input                AUD_BCLK,
    output  logic        AUD_XCK,
    input                AUD_ADCLRCK,
    output [6:0] HEX0,
	output [6:0] HEX1,
	output [6:0] HEX2,
	output [6:0] HEX3,
	output [6:0] HEX4,
	output [6:0] HEX5,
	output [6:0] HEX6,
	output [6:0] HEX7,
);
    logic enable;
    logic measure_pulse;

    logic rst_n;
    logic ready;
    logic echo;
    logic trig;

    assign echo = GPIO[27];  // Echo input from pin 27
    assign GPIO[29] = trig;  // Trig output to pin 29
    
    logic [21:0] distanceRAW;

    logic [3:0] key_edge;
    logic [3:0] key_debounced;

    assign enable = 1'b1;
    assign rst_n = key_debounced[0];

    assign LEDG[0] = rst_n;

    debounce_keys u_debounce_keys (
        .clk(CLOCK_50),
        .buttons(KEYS),         
        .key_edge(key_edge),
        .key_debounced(key_debounced)
    );

    refresher250ms u_refresher250ms (
        .clk(CLOCK_50),
        .en(enable),
        .measure(measure_pulse) // Will pulse high for one clock cycle every 250ms
    );

    // Use the measure pulse with your proximity sensor
    proximity_sensor u_proximity_sensor (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .measure(measure_pulse), // Connect the 250ms pulse here
        .ready(ready),
        .echo(echo),
        .trig(trig),
        .distanceRAW(distanceRAW)
    );

    microphone_top_level u_microphone_top_level (
        .CLOCK_50(CLOCK_50),
        .KEY(KEYS),
        .whistle_detected(LEDG[7]), // Output whistle detection to LEDG[7]
        .beep_detected(LEDG[8]),
        .LEDR(),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7),
        .AUD_ADCDAT(AUD_ADCDAT),
        .AUD_BCLK(AUD_BCLK),
        .AUD_XCK(AUD_XCK),
        .AUD_ADCLRCK(AUD_ADCDAT)
    );
    
    // Show raw value differently
    assign LEDR = distanceRAW[21:4];  // Top 18 bits

endmodule