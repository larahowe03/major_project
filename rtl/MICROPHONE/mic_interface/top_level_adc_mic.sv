module top_level_adc_mic (
    input                CLOCK_50,
    output  logic        I2C_SCLK,
    inout                I2C_SDAT,
    input                AUD_ADCDAT,
    input                AUD_BCLK,
    output  logic        AUD_XCK,
    input                AUD_ADCLRCK,
    output  logic [15:0] data,
    output  logic        data_valid
);

    logic adc_clk; adc_pll adc_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(adc_clk)); // Generate 18.432 MHz clock
    logic i2c_clk; i2c_pll i2c_pll_u (.areset(1'b0),.inclk0(CLOCK_50),.c0(i2c_clk)); // Generate 20 kHz clock

    set_audio_encoder set_codec_u (.i2c_clk(i2c_clk), .I2C_SCLK(I2C_SCLK), .I2C_SDAT(I2C_SDAT));
                
    mic_load #(.N(16)) u_mic_load (
        .adclrc(AUD_ADCLRCK),
        .bclk(AUD_BCLK),
        .adcdat(AUD_ADCDAT),
        .sample_data(data)
    );
    
    assign AUD_XCK = adc_clk;

    // sending data valid signal
    logic lrclk_prev;

    always_ff @(posedge CLOCK_50) begin
        lrclk_prev <= AUD_ADCLRCK;
        // 1-cycle pulse on LRCLK rising edge
        data_valid <= (AUD_ADCLRCK && !lrclk_prev);
    end
        
endmodule
