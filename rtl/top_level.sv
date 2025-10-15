module top_level (
    input CLOCK_50,
    input [3:0] KEYS
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
endmodule