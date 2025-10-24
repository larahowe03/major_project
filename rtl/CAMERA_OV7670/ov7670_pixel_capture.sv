/*  OV7670 Pixel Capture with 90° Clockwise Rotation
 *
 *  Takes data inputs from OV7670 camera and scales image down from 640x480 -> 320x240.
 *  The image is stored in memory rotated 90° clockwise for correct orientation on VGA.
 *
 *  Notes:
 *  - Requires OV7670 configured for RGB444 output (register 0x8C).
 *  - PCLK ≈ 50MHz, ensure timing constraints are set properly.
 */

module ov7670_pixel_capture(
    input  wire        pclk,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  d,
    output wire [16:0] addr,
    output wire [11:0] pixel,
    output wire        we
);

    // --------------------------
    // Parameters
    // --------------------------
    localparam IMG_W = 320;
    localparam IMG_H = 240;

    // --------------------------
    // Color components
    // --------------------------
    reg [3:0] red   = 4'b0;
    reg [3:0] green = 4'b0;
    reg [3:0] blue  = 4'b0;
    assign pixel = {red, green, blue};

    // --------------------------
    // Position tracking
    // --------------------------
    reg [8:0] x_pos = 0;  // 0–319
    reg [7:0] y_pos = 0;  // 0–239

    // --------------------------
    // Control flags
    // --------------------------
    reg pixel_phase   = 0;
    reg pixel_ready   = 0;
    reg x_downscaler  = 0;
    reg y_downscaler  = 0;
    reg href_last     = 0;

    // --------------------------
    // Capture logic
    // --------------------------
    always_ff @(posedge pclk) begin
        pixel_ready <= 1'b0;
        href_last   <= href;

        if (vsync) begin
            x_pos        <= 0;
            y_pos        <= 0;
            pixel_phase  <= 0;
            x_downscaler <= 0;
            y_downscaler <= 0;
        end 
        else if (href) begin
            pixel_phase <= ~pixel_phase;

            if (href_last != href)
                y_downscaler <= ~y_downscaler;

            if (pixel_phase == 1'b0) begin
                red <= d[3:0];  // First byte: XXXXRRRR
            end 
            else begin
                blue  <= d[3:0];   // Second byte: GGGGBBBB
                green <= d[7:4];
                pixel_ready <= 1'b1;
                x_downscaler <= ~x_downscaler;
            end

            // Update X,Y positions only when writing
            if (we) begin
                if (x_pos == IMG_W - 1) begin
                    x_pos <= 0;
                    if (y_pos == IMG_H - 1)
                        y_pos <= 0;
                    else
                        y_pos <= y_pos + 1;
                end else begin
                    x_pos <= x_pos + 1;
                end
            end
        end
    end

    // --------------------------
    // 90° clockwise rotated address mapping
    // --------------------------
    // Normally: addr = y * IMG_W + x
    // Rotated:  addr = (IMG_W - 1 - y) + (x * IMG_W)
    wire [16:0] rotated_addr = ((IMG_W - 1 - y_pos) * IMG_H / IMG_W) + x_pos * IMG_H / IMG_W;
//    assign addr = rotated_addr;
	 
	 assign addr = (IMG_H - 1 - y_pos) * IMG_W + x_pos;

    // --------------------------
    // Write enable
    // --------------------------
    assign we = x_downscaler & y_downscaler & pixel_ready;

endmodule
