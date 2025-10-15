module top_level (
    input CLOCK_50,
    input [3:0] KEYS,
    output [9:0] LEDR
);
    logic enable;
    logic measure_pulse;

    logic rst_n;
    logic ready;
    logic echo;
    logic trig;
    logic [21:0] distanceRAW;

    logic [3:0] key_edge;
    logic [3:0] key_debounced;

    assign enable = 1'b1;
    assign rst_n = key_debounced[0];

    module debounce_keys u_debounce_keys (
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

    // Bar graph style (closer = more LEDs)
    // Scale distance and show as bar graph
    logic [3:0] distance_scaled;
    assign distance_scaled = distanceRAW[21:18]; // Use top 4 bits
    
    always_comb begin
        case (distance_scaled)
            4'd0, 4'd1:  LEDR = 10'b1111111111; // Very close - all LEDs
            4'd2, 4'd3:  LEDR = 10'b0111111111; // Close - 9 LEDs
            4'd4, 4'd5:  LEDR = 10'b0011111111; // Medium - 8 LEDs
            4'd6, 4'd7:  LEDR = 10'b0001111111; // 7 LEDs
            4'd8, 4'd9:  LEDR = 10'b0000111111; // 6 LEDs
            4'd10, 4'd11: LEDR = 10'b0000011111; // 5 LEDs
            4'd12, 4'd13: LEDR = 10'b0000001111; // Far - 4 LEDs
            4'd14:       LEDR = 10'b0000000111; // Very far - 3 LEDs
            default:     LEDR = 10'b0000000001; // Too far - 1 LED
        endcase
    end

endmodule