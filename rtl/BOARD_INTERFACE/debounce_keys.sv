module debounce_keys #(
    parameter N = 4,                       // Number of buttons
    parameter DELAY_COUNTS = 2500         // 50 µs for 20ns clock
)(
    input  logic clk,
    input  logic [N-1:0] buttons,         // Raw button inputs
    output logic [N-1:0] key_edge,        // One-cycle rising edge pulses
    output logic [N-1:0] key_debounced    // Debounced button states
);

    logic [N-1:0] debounced;
    logic [N-1:0] prev;

    // Generate N debounce modules using a generate loop
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : debounce_loop
            debounce #(.DELAY_COUNTS(DELAY_COUNTS)) db (
                .clk(clk),
                .button(buttons[i]),
                .button_pressed(debounced[i])
            );
        end
    endgenerate

    // Register outputs and detect rising edges
    always_ff @(posedge clk) begin
        key_edge       <= debounced & ~prev;  // Rising edge detection
        key_debounced  <= debounced;          // Current debounced value
        prev           <= debounced;          // Store previous debounced value
    end

endmodule