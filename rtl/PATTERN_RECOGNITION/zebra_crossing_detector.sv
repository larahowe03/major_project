module zebra_crossing_detector #(
    parameter IMG_WIDTH = 640,
    parameter IMG_HEIGHT = 480,
    parameter W = 8
)(
    input logic clk,
    input logic rst_n,
    
    // Input from convolution filter (edge-detected pixels)
    input logic pixel_valid,
    input logic [W-1:0] edge_pixel,
    
    // Outputs
    output logic crossing_detected,
    output logic detection_valid,  // Pulses high when new detection is ready
    output logic [7:0] stripe_count,  // Number of stripes detected (for debugging)
    output logic [15:0] confidence    // Detection confidence score
);

    // ========================================================================
    // Position tracking
    // ========================================================================

    // travel the image pixel by pixel
    logic [$clog2(IMG_WIDTH)-1:0] x_pos;
    logic [$clog2(IMG_HEIGHT)-1:0] y_pos;
    
    // storing the filtered image for analysis
    localparam NumPixels = IMG_WIDTH * IMG_HEIGHT;
    logic [W-1:0] filtered_image [0:NumPixels-1];

    typedef enum {IDLE, READ_IMAGE, PROCESS_IMAGE} current_state, next_state;

    always_comb begin : next_state_logic
        case (current_state)
            IDLE: begin
                if (pixel_valid)
                    next_state = READ_IMAGE;
                else
                    next_state = IDLE;
            end
            READ_IMAGE: begin
                if (x_pos == IMG_WIDTH - 1 && y_pos == IMG_HEIGHT - 1)
                    next_state = PROCESS_IMAGE;
                else
                    next_state = READ_IMAGE;
            end
            PROCESS_IMAGE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // next state register
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // store incoming pixels into filtered_image array 
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_pos <= '0;
            y_pos <= '0;
        end else if (current_state == READ_IMAGE && pixel_valid) begin
            filtered_image[y_pos * IMG_WIDTH + x_pos] <= edge_pixel;
            if (x_pos == IMG_WIDTH - 1) begin
                x_pos <= '0;
                y_pos <= (y_pos == IMG_HEIGHT - 1) ? '0 : y_pos + 1;
            end else begin
                x_pos <= x_pos + 1;
            end
        end
    end

    // ========================================================================
    // Detection parameters
    // ========================================================================
    localparam EDGE_THRESHOLD = 8'd50;      // Pixel value above this = "is edge"
    localparam MIN_EDGES_PER_ROW = 80;      // Min edges to count as stripe row
    localparam MIN_STRIPES = 4;             // Min stripe rows for crossing
    localparam MAX_STRIPES = 15;            // Max stripe rows for crossing

    // ========================================================================
    // Zebra crossing detection logic   
    // ========================================================================

    logic processing_initialised;
    logic line_detected;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing_initialised <= 1'b0;
            line_detected <= 1'b0;
        end else if (current_state == PROCESS_IMAGE) begin
            // initially setting the x and y positions to the bottom of the image
            if (!processing_initialised) begin
                processing_initialised <= 1'b1;
                x_pos <= IMG_WIDTH / 2;
                y_pos <= IMAGE_HEIGHT - 1;
            end else begin
                if (!line_detected) begin
                    // Travel up the image to find a crossing
                    y_pos <= y_pos - 1'b1;
                    if filtered_image[y_pos * IMG_WIDTH + x_pos] > EDGE_THRESHOLD begin
                        line_detected <= 1'b1;
                    end
                end else begin
                    // if a line is detected travel around that pixel to 
                end
            end
        end
    end
            
endmodule