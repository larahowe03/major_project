module vga_streaming #(
    parameter WIDTH  = 640,
    parameter HEIGHT = 480,
    parameter PIXEL_BITS = 8 // GRAYSCALE = 8
)(
    input logic clk,
    input logic reset,

    // Input from convolution filter
    input logic pixel_valid,
    input logic [PIXEL_BITS-1:0] filtered_pixel,
    output logic pixel_ready,

    // Avalon-ST Interface (to VGA)
    output logic [29:0] data,
    output logic startofpacket,
    output logic endofpacket,
    output logic valid,
    input  logic ready
);

    // ================== Parameters ==================
    localparam NumPixels = WIDTH * HEIGHT;

    // ================== Pixel Counter ==================
    logic [$clog2(NumPixels)-1:0] pixel_index;
    
    // Register to hold current pixel
    logic [PIXEL_BITS-1:0] pixel_q;
    
    // Handshaking
    logic advance;
    assign advance = valid & ready;
    
    // We're ready to accept pixels when VGA is ready (or in reset)
    assign pixel_ready = ready | reset;
    
    // Capture incoming filtered pixel
    always_ff @(posedge clk) begin
        if (pixel_valid && pixel_ready) begin
            pixel_q <= filtered_pixel;
        end
    end
    
    // ================== Pixel Index Management ==================
    always_ff @(posedge clk or negedge reset) begin
        if (!reset) begin
            pixel_index <= 0;
        end else if (advance) begin
            if (pixel_index == NumPixels - 1)
                pixel_index <= 0;
            else
                pixel_index <= pixel_index + 1;
        end
    end
    
    // ================== VGA Output Signals ==================
    assign valid = pixel_valid;
    
    assign startofpacket = (pixel_index == 0);
    assign endofpacket = (pixel_index == NumPixels - 1);
    
    // ================== Data Output for Grayscale ==================
    // Replicate grayscale value across RGB channels (10 bits each with 2-bit padding)
    assign data = {
        {pixel_q, 2'b00},  // R
        {pixel_q, 2'b00},  // G
        {pixel_q, 2'b00}   // B
    };

endmodule