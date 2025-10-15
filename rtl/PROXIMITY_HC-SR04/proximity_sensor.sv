// ****************************************************************
// This is based on the code from https://github.com/suoglu/HC-SR04
// ****************************************************************

module proximity_sensor #(
    parameter TEN_US = 10'd500 // ten microseconds
)(
    input CLOCK_50, //50 MHz
    input rst_n,
    input measure,
    // output logic [1:0] state,
    output ready,
    //HC-SR04 signals
    input echo, //JA1
    output trig, //JA2
    output logic [21:0] distanceRAW
);

    // State variables
    enum {Idle, Trigger, Wait, CountEcho} next_state, current_state; 

    // Counter variables
    logic [9:0] counter;
    logic trigCountDone, counterDONE;

    // Distance register variable
    logic [21:0] distanceRAW_reg;

    // Next state logic
    always_comb begin
        next_state = current_state;
        case (current_state) 
            Idle:      if (measure & ready) next_state = Trigger;
            Trigger:   if (trigCountDone) next_state = Wait;
            Wait:      if (echo) next_state = CountEcho;
            CountEcho: if (!echo) next_state = Idle;
            default:   next_state = Idle;
        endcase
    end

    // State transitions
    always_ff @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= Idle;
            counter <= '0;
            distanceRAW_reg <= '0;
        end else begin
            case (current_state)
                Idle: begin
                    counter <= '0;
                end
                Trigger: begin
                    counter <= counter + '1;
                end
                Wait: begin
                    distanceRAW_reg <= '0;
                    counter <= counter + '1;
                end
                CountEcho: begin
                    distanceRAW_reg <= distanceRAW_reg + '1;
                    counter <= counter + '1;
                end
            endcase
            current_state <= next_state;
        end
    end
    
    assign trigCountDone = (counter == TEN_US);

    // Outputs
    assign ready = (current_state == Idle);
    assign trig = (current_state == Trigger);
    assign distanceRAW = distanceRAW_reg;

endmodule