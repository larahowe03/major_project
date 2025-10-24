//----------------------------------------------------------------------
//  Twiddle: 256-Point Twiddle Table for Radix-2^2 Butterfly
//----------------------------------------------------------------------
module Twiddle #(
    parameter   TW_FF = 1   //  Use Output Register
)(
    input           clock,  //  Master Clock
    input   [9:0]   addr,   //  Twiddle Factor Number
    output  [15:0]  tw_re,  //  Twiddle Factor (Real)
    output  [15:0]  tw_im   //  Twiddle Factor (Imag)
);

wire[15:0]  wn_re[0:255];  //  Twiddle Table (Real)
wire[15:0]  wn_im[0:255];  //  Twiddle Table (Imag)
wire[15:0]  mx_re;          //  Multiplexer output (Real)
wire[15:0]  mx_im;          //  Multiplexer output (Imag)
reg [15:0]  ff_re;          //  Register output (Real)
reg [15:0]  ff_im;          //  Register output (Imag)

// assign  mx_re = wn_re[addr];
// assign  mx_im = wn_im[addr];
wire [7:0] addr8 = addr[7:0];
assign mx_re = wn_re[addr8];
assign mx_im = wn_im[addr8];

always @(posedge clock) begin
    ff_re <= mx_re;
    ff_im <= mx_im;
end

assign  tw_re = TW_FF ? ff_re : mx_re;
assign  tw_im = TW_FF ? ff_im : mx_im;


//----------------------------------------------------------------------
//  Twiddle Factor Value
//----------------------------------------------------------------------
//  Multiplication is bypassed when twiddle address is 0.
//  Setting wn_re[0] = 0 and wn_im[0] = 0 makes it easier to check the waveform.
//  It may also reduce power consumption slightly.
//      wn_re = cos(-2pi*n/256)          wn_im = sin(-2pi*n/256)
assign  wn_re[ 0] = 16'h0000;   assign  wn_im[ 0] = 16'h0000;   //  0  1.000 -0.000
assign  wn_re[ 1] = 16'h2182;   assign  wn_im[ 1] = 16'hD541;   //  1  1.000 -0.025
assign  wn_re[ 2] = 16'h878E;   assign  wn_im[ 2] = 16'h2684;   //  2  0.999 -0.049
assign  wn_re[ 3] = 16'h36B4;   assign  wn_im[ 3] = 16'h6FB7;   //  3  0.997 -0.074
assign  wn_re[ 4] = 16'h368F;   assign  wn_im[ 4] = 16'h2CA2;   //  4  0.995 -0.098
assign  wn_re[ 5] = 16'h91C4;   assign  wn_im[ 5] = 16'hD8D5;   //  5  0.992 -0.122
assign  wn_re[ 6] = 16'h55FC;   assign  wn_im[ 6] = 16'hEF91;   //  6  0.989 -0.147
assign  wn_re[ 7] = 16'h93EA;   assign  wn_im[ 7] = 16'hEBBB;   //  7  0.985 -0.171
assign  wn_re[ 8] = 16'h5F40;   assign  wn_im[ 8] = 16'h47C4;   //  8  0.981 -0.195
assign  wn_re[ 9] = 16'hCEB2;   assign  wn_im[ 9] = 16'h7D96;   //  9  0.976 -0.219
assign  wn_re[10] = 16'hFBEE;   assign  wn_im[10] = 16'h0685;   // 10  0.970 -0.243
assign  wn_re[11] = 16'h039E;   assign  wn_im[11] = 16'h5B3B;   // 11  0.964 -0.267
assign  wn_re[12] = 16'h055B;   assign  wn_im[12] = 16'hF3A2;   // 12  0.957 -0.290
assign  wn_re[13] = 16'h23B1;   assign  wn_im[13] = 16'h46D8;   // 13  0.950 -0.314
assign  wn_re[14] = 16'h8414;   assign  wn_im[14] = 16'hCB15;   // 14  0.942 -0.337
assign  wn_re[15] = 16'h4EDB;   assign  wn_im[15] = 16'hF59E;   // 15  0.933 -0.360
assign  wn_re[16] = 16'hAF3D;   assign  wn_im[16] = 16'h3AB3;   // 16  0.924 -0.383
assign  wn_re[17] = 16'hD345;   assign  wn_im[17] = 16'h0D79;   // 17  0.914 -0.405
assign  wn_re[18] = 16'hEBD1;   assign  wn_im[18] = 16'hDFEC;   // 18  0.904 -0.428
assign  wn_re[19] = 16'h2C85;   assign  wn_im[19] = 16'h22CE;   // 19  0.893 -0.450
assign  wn_re[20] = 16'hCBC6;   assign  wn_im[20] = 16'h4590;   // 20  0.882 -0.471
assign  wn_re[21] = 16'h02B2;   assign  wn_im[21] = 16'hB648;   // 21  0.870 -0.493
assign  wn_re[22] = 16'h0D14;   assign  wn_im[22] = 16'hE19B;   // 22  0.858 -0.514
assign  wn_re[23] = 16'h2960;   assign  wn_im[23] = 16'h32B0;   // 23  0.845 -0.535
assign  wn_re[24] = 16'h98A4;   assign  wn_im[24] = 16'h1319;   // 24  0.831 -0.556
assign  wn_re[25] = 16'h9E81;   assign  wn_im[25] = 16'hEACD;   // 25  0.818 -0.576
assign  wn_re[26] = 16'h8120;   assign  wn_im[26] = 16'h200C;   // 26  0.803 -0.596
assign  wn_re[27] = 16'h8926;   assign  wn_im[27] = 16'h175B;   // 27  0.788 -0.615
assign  wn_re[28] = 16'h01AC;   assign  wn_im[28] = 16'h336C;   // 28  0.773 -0.634
assign  wn_re[29] = 16'h3830;   assign  wn_im[29] = 16'hD510;   // 29  0.757 -0.653
assign  wn_re[30] = 16'h7C8A;   assign  wn_im[30] = 16'h5B2E;   // 30  0.741 -0.672
assign  wn_re[31] = 16'h20E0;   assign  wn_im[31] = 16'h22AC;   // 31  0.724 -0.690
assign  wn_re[32] = 16'h799A;   assign  wn_im[32] = 16'h8666;   // 32  0.707 -0.707
assign  wn_re[33] = 16'hDD54;   assign  wn_im[33] = 16'hDF20;   // 33  0.690 -0.724
assign  wn_re[34] = 16'hA4D2;   assign  wn_im[34] = 16'h8376;   // 34  0.672 -0.741
assign  wn_re[35] = 16'h2AF0;   assign  wn_im[35] = 16'hC7D0;   // 35  0.653 -0.757
assign  wn_re[36] = 16'hCC94;   assign  wn_im[36] = 16'hFE54;   // 36  0.634 -0.773
assign  wn_re[37] = 16'hE8A5;   assign  wn_im[37] = 16'h76DA;   // 37  0.615 -0.788
assign  wn_re[38] = 16'hDFF4;   assign  wn_im[38] = 16'h7EE0;   // 38  0.596 -0.803
assign  wn_re[39] = 16'h1533;   assign  wn_im[39] = 16'h617F;   // 39  0.576 -0.818
assign  wn_re[40] = 16'hECE7;   assign  wn_im[40] = 16'h675C;   // 40  0.556 -0.831
assign  wn_re[41] = 16'hCD50;   assign  wn_im[41] = 16'hD6A0;   // 41  0.535 -0.845
assign  wn_re[42] = 16'h1E65;   assign  wn_im[42] = 16'hF2EC;   // 42  0.514 -0.858
assign  wn_re[43] = 16'h49B8;   assign  wn_im[43] = 16'hFD4E;   // 43  0.493 -0.870
assign  wn_re[44] = 16'hBA70;   assign  wn_im[44] = 16'h343A;   // 44  0.471 -0.882
assign  wn_re[45] = 16'hDD32;   assign  wn_im[45] = 16'hD37B;   // 45  0.450 -0.893
assign  wn_re[46] = 16'h2014;   assign  wn_im[46] = 16'h142F;   // 46  0.428 -0.904
assign  wn_re[47] = 16'hF287;   assign  wn_im[47] = 16'h2CBB;   // 47  0.405 -0.914
assign  wn_re[48] = 16'hC54D;   assign  wn_im[48] = 16'h50C3;   // 48  0.383 -0.924
assign  wn_re[49] = 16'h0A62;   assign  wn_im[49] = 16'hB125;   // 49  0.360 -0.933
assign  wn_re[50] = 16'h34EB;   assign  wn_im[50] = 16'h7BEC;   // 50  0.337 -0.942
assign  wn_re[51] = 16'hB928;   assign  wn_im[51] = 16'hDC4F;   // 51  0.314 -0.950
assign  wn_re[52] = 16'h0C5E;   assign  wn_im[52] = 16'hFAA5;   // 52  0.290 -0.957
assign  wn_re[53] = 16'hA4C5;   assign  wn_im[53] = 16'hFC62;   // 53  0.267 -0.964
assign  wn_re[54] = 16'hF97B;   assign  wn_im[54] = 16'h0412;   // 54  0.243 -0.970
assign  wn_re[55] = 16'h826A;   assign  wn_im[55] = 16'h314E;   // 55  0.219 -0.976
assign  wn_re[56] = 16'hB83C;   assign  wn_im[56] = 16'hA0C0;   // 56  0.195 -0.981
assign  wn_re[57] = 16'h1445;   assign  wn_im[57] = 16'h6C16;   // 57  0.171 -0.985
assign  wn_re[58] = 16'h106F;   assign  wn_im[58] = 16'hAA04;   // 58  0.147 -0.989
assign  wn_re[59] = 16'h272B;   assign  wn_im[59] = 16'h6E3C;   // 59  0.122 -0.992
assign  wn_re[60] = 16'hD35E;   assign  wn_im[60] = 16'hC971;   // 60  0.098 -0.995
assign  wn_re[61] = 16'h9049;   assign  wn_im[61] = 16'hC94C;   // 61  0.074 -0.997
assign  wn_re[62] = 16'hD97C;   assign  wn_im[62] = 16'h7872;   // 62  0.049 -0.999
assign  wn_re[63] = 16'h2ABF;   assign  wn_im[63] = 16'hDE7E;   // 63  0.025 -1.000
assign  wn_re[64] = 16'h0000;   assign  wn_im[64] = 16'h0000;   // 64  0.000 -1.000
assign  wn_re[65] = 16'h0000;   assign  wn_im[65] = 16'h0000;   // 65 -0.025 -1.000
assign  wn_re[66] = 16'h2684;   assign  wn_im[66] = 16'h7872;   // 66 -0.049 -0.999
assign  wn_re[67] = 16'h0000;   assign  wn_im[67] = 16'h0000;   // 67 -0.074 -0.997
assign  wn_re[68] = 16'h2CA2;   assign  wn_im[68] = 16'hC971;   // 68 -0.098 -0.995
assign  wn_re[69] = 16'hD8D5;   assign  wn_im[69] = 16'h6E3C;   // 69 -0.122 -0.992
assign  wn_re[70] = 16'hEF91;   assign  wn_im[70] = 16'hAA04;   // 70 -0.147 -0.989
assign  wn_re[71] = 16'h0000;   assign  wn_im[71] = 16'h0000;   // 71 -0.171 -0.985
assign  wn_re[72] = 16'h47C4;   assign  wn_im[72] = 16'hA0C0;   // 72 -0.195 -0.981
assign  wn_re[73] = 16'h0000;   assign  wn_im[73] = 16'h0000;   // 73 -0.219 -0.976
assign  wn_re[74] = 16'h0685;   assign  wn_im[74] = 16'h0412;   // 74 -0.243 -0.970
assign  wn_re[75] = 16'h5B3B;   assign  wn_im[75] = 16'hFC62;   // 75 -0.267 -0.964
assign  wn_re[76] = 16'hF3A2;   assign  wn_im[76] = 16'hFAA5;   // 76 -0.290 -0.957
assign  wn_re[77] = 16'h0000;   assign  wn_im[77] = 16'h0000;   // 77 -0.314 -0.950
assign  wn_re[78] = 16'hCB15;   assign  wn_im[78] = 16'h7BEC;   // 78 -0.337 -0.942
assign  wn_re[79] = 16'h0000;   assign  wn_im[79] = 16'h0000;   // 79 -0.360 -0.933
assign  wn_re[80] = 16'h3AB3;   assign  wn_im[80] = 16'h50C3;   // 80 -0.383 -0.924
assign  wn_re[81] = 16'h0D79;   assign  wn_im[81] = 16'h2CBB;   // 81 -0.405 -0.914
assign  wn_re[82] = 16'hDFEC;   assign  wn_im[82] = 16'h142F;   // 82 -0.428 -0.904
assign  wn_re[83] = 16'h0000;   assign  wn_im[83] = 16'h0000;   // 83 -0.450 -0.893
assign  wn_re[84] = 16'h4590;   assign  wn_im[84] = 16'h343A;   // 84 -0.471 -0.882
assign  wn_re[85] = 16'h0000;   assign  wn_im[85] = 16'h0000;   // 85 -0.493 -0.870
assign  wn_re[86] = 16'hE19B;   assign  wn_im[86] = 16'hF2EC;   // 86 -0.514 -0.858
assign  wn_re[87] = 16'h32B0;   assign  wn_im[87] = 16'hD6A0;   // 87 -0.535 -0.845
assign  wn_re[88] = 16'h1319;   assign  wn_im[88] = 16'h675C;   // 88 -0.556 -0.831
assign  wn_re[89] = 16'h0000;   assign  wn_im[89] = 16'h0000;   // 89 -0.576 -0.818
assign  wn_re[90] = 16'h200C;   assign  wn_im[90] = 16'h7EE0;   // 90 -0.596 -0.803
assign  wn_re[91] = 16'h0000;   assign  wn_im[91] = 16'h0000;   // 91 -0.615 -0.788
assign  wn_re[92] = 16'h336C;   assign  wn_im[92] = 16'hFE54;   // 92 -0.634 -0.773
assign  wn_re[93] = 16'hD510;   assign  wn_im[93] = 16'hC7D0;   // 93 -0.653 -0.757
assign  wn_re[94] = 16'h5B2E;   assign  wn_im[94] = 16'h8376;   // 94 -0.672 -0.741
assign  wn_re[95] = 16'h0000;   assign  wn_im[95] = 16'h0000;   // 95 -0.690 -0.724
assign  wn_re[96] = 16'h8666;   assign  wn_im[96] = 16'h8666;   // 96 -0.707 -0.707
assign  wn_re[97] = 16'h0000;   assign  wn_im[97] = 16'h0000;   // 97 -0.724 -0.690
assign  wn_re[98] = 16'h8376;   assign  wn_im[98] = 16'h5B2E;   // 98 -0.741 -0.672
assign  wn_re[99] = 16'hC7D0;   assign  wn_im[99] = 16'hD510;   // 99 -0.757 -0.653
assign  wn_re[100] = 16'hFE54;   assign  wn_im[100] = 16'h336C;   // 100 -0.773 -0.634
assign  wn_re[101] = 16'h0000;   assign  wn_im[101] = 16'h0000;   // 101 -0.788 -0.615
assign  wn_re[102] = 16'h7EE0;   assign  wn_im[102] = 16'h200C;   // 102 -0.803 -0.596
assign  wn_re[103] = 16'h0000;   assign  wn_im[103] = 16'h0000;   // 103 -0.818 -0.576
assign  wn_re[104] = 16'h675C;   assign  wn_im[104] = 16'h1319;   // 104 -0.831 -0.556
assign  wn_re[105] = 16'hD6A0;   assign  wn_im[105] = 16'h32B0;   // 105 -0.845 -0.535
assign  wn_re[106] = 16'hF2EC;   assign  wn_im[106] = 16'hE19B;   // 106 -0.858 -0.514
assign  wn_re[107] = 16'h0000;   assign  wn_im[107] = 16'h0000;   // 107 -0.870 -0.493
assign  wn_re[108] = 16'h343A;   assign  wn_im[108] = 16'h4590;   // 108 -0.882 -0.471
assign  wn_re[109] = 16'h0000;   assign  wn_im[109] = 16'h0000;   // 109 -0.893 -0.450
assign  wn_re[110] = 16'h142F;   assign  wn_im[110] = 16'hDFEC;   // 110 -0.904 -0.428
assign  wn_re[111] = 16'h2CBB;   assign  wn_im[111] = 16'h0D79;   // 111 -0.914 -0.405
assign  wn_re[112] = 16'h50C3;   assign  wn_im[112] = 16'h3AB3;   // 112 -0.924 -0.383
assign  wn_re[113] = 16'h0000;   assign  wn_im[113] = 16'h0000;   // 113 -0.933 -0.360
assign  wn_re[114] = 16'h7BEC;   assign  wn_im[114] = 16'hCB15;   // 114 -0.942 -0.337
assign  wn_re[115] = 16'h0000;   assign  wn_im[115] = 16'h0000;   // 115 -0.950 -0.314
assign  wn_re[116] = 16'hFAA5;   assign  wn_im[116] = 16'hF3A2;   // 116 -0.957 -0.290
assign  wn_re[117] = 16'hFC62;   assign  wn_im[117] = 16'h5B3B;   // 117 -0.964 -0.267
assign  wn_re[118] = 16'h0412;   assign  wn_im[118] = 16'h0685;   // 118 -0.970 -0.243
assign  wn_re[119] = 16'h0000;   assign  wn_im[119] = 16'h0000;   // 119 -0.976 -0.219
assign  wn_re[120] = 16'hA0C0;   assign  wn_im[120] = 16'h47C4;   // 120 -0.981 -0.195
assign  wn_re[121] = 16'h0000;   assign  wn_im[121] = 16'h0000;   // 121 -0.985 -0.171
assign  wn_re[122] = 16'hAA04;   assign  wn_im[122] = 16'hEF91;   // 122 -0.989 -0.147
assign  wn_re[123] = 16'h6E3C;   assign  wn_im[123] = 16'hD8D5;   // 123 -0.992 -0.122
assign  wn_re[124] = 16'hC971;   assign  wn_im[124] = 16'h2CA2;   // 124 -0.995 -0.098
assign  wn_re[125] = 16'h0000;   assign  wn_im[125] = 16'h0000;   // 125 -0.997 -0.074
assign  wn_re[126] = 16'h7872;   assign  wn_im[126] = 16'h2684;   // 126 -0.999 -0.049
assign  wn_re[127] = 16'h0000;   assign  wn_im[127] = 16'h0000;   // 127 -1.000 -0.025
assign  wn_re[128] = 16'h0000;   assign  wn_im[128] = 16'h0000;   // 128 -1.000 -0.000
assign  wn_re[129] = 16'hDE7E;   assign  wn_im[129] = 16'h2ABF;   // 129 -1.000  0.025
assign  wn_re[130] = 16'h0000;   assign  wn_im[130] = 16'h0000;   // 130 -0.999  0.049
assign  wn_re[131] = 16'h0000;   assign  wn_im[131] = 16'h0000;   // 131 -0.997  0.074
assign  wn_re[132] = 16'hC971;   assign  wn_im[132] = 16'hD35E;   // 132 -0.995  0.098
assign  wn_re[133] = 16'h0000;   assign  wn_im[133] = 16'h0000;   // 133 -0.992  0.122
assign  wn_re[134] = 16'h0000;   assign  wn_im[134] = 16'h0000;   // 134 -0.989  0.147
assign  wn_re[135] = 16'h6C16;   assign  wn_im[135] = 16'h1445;   // 135 -0.985  0.171
assign  wn_re[136] = 16'h0000;   assign  wn_im[136] = 16'h0000;   // 136 -0.981  0.195
assign  wn_re[137] = 16'h0000;   assign  wn_im[137] = 16'h0000;   // 137 -0.976  0.219
assign  wn_re[138] = 16'h0412;   assign  wn_im[138] = 16'hF97B;   // 138 -0.970  0.243
assign  wn_re[139] = 16'h0000;   assign  wn_im[139] = 16'h0000;   // 139 -0.964  0.267
assign  wn_re[140] = 16'h0000;   assign  wn_im[140] = 16'h0000;   // 140 -0.957  0.290
assign  wn_re[141] = 16'hDC4F;   assign  wn_im[141] = 16'hB928;   // 141 -0.950  0.314
assign  wn_re[142] = 16'h0000;   assign  wn_im[142] = 16'h0000;   // 142 -0.942  0.337
assign  wn_re[143] = 16'h0000;   assign  wn_im[143] = 16'h0000;   // 143 -0.933  0.360
assign  wn_re[144] = 16'h50C3;   assign  wn_im[144] = 16'hC54D;   // 144 -0.924  0.383
assign  wn_re[145] = 16'h0000;   assign  wn_im[145] = 16'h0000;   // 145 -0.914  0.405
assign  wn_re[146] = 16'h0000;   assign  wn_im[146] = 16'h0000;   // 146 -0.904  0.428
assign  wn_re[147] = 16'hD37B;   assign  wn_im[147] = 16'hDD32;   // 147 -0.893  0.450
assign  wn_re[148] = 16'h0000;   assign  wn_im[148] = 16'h0000;   // 148 -0.882  0.471
assign  wn_re[149] = 16'h0000;   assign  wn_im[149] = 16'h0000;   // 149 -0.870  0.493
assign  wn_re[150] = 16'hF2EC;   assign  wn_im[150] = 16'h1E65;   // 150 -0.858  0.514
assign  wn_re[151] = 16'h0000;   assign  wn_im[151] = 16'h0000;   // 151 -0.845  0.535
assign  wn_re[152] = 16'h0000;   assign  wn_im[152] = 16'h0000;   // 152 -0.831  0.556
assign  wn_re[153] = 16'h617F;   assign  wn_im[153] = 16'h1533;   // 153 -0.818  0.576
assign  wn_re[154] = 16'h0000;   assign  wn_im[154] = 16'h0000;   // 154 -0.803  0.596
assign  wn_re[155] = 16'h0000;   assign  wn_im[155] = 16'h0000;   // 155 -0.788  0.615
assign  wn_re[156] = 16'hFE54;   assign  wn_im[156] = 16'hCC94;   // 156 -0.773  0.634
assign  wn_re[157] = 16'h0000;   assign  wn_im[157] = 16'h0000;   // 157 -0.757  0.653
assign  wn_re[158] = 16'h0000;   assign  wn_im[158] = 16'h0000;   // 158 -0.741  0.672
assign  wn_re[159] = 16'hDF20;   assign  wn_im[159] = 16'hDD54;   // 159 -0.724  0.690
assign  wn_re[160] = 16'h0000;   assign  wn_im[160] = 16'h0000;   // 160 -0.707  0.707
assign  wn_re[161] = 16'h0000;   assign  wn_im[161] = 16'h0000;   // 161 -0.690  0.724
assign  wn_re[162] = 16'h5B2E;   assign  wn_im[162] = 16'h7C8A;   // 162 -0.672  0.741
assign  wn_re[163] = 16'h0000;   assign  wn_im[163] = 16'h0000;   // 163 -0.653  0.757
assign  wn_re[164] = 16'h0000;   assign  wn_im[164] = 16'h0000;   // 164 -0.634  0.773
assign  wn_re[165] = 16'h175B;   assign  wn_im[165] = 16'h8926;   // 165 -0.615  0.788
assign  wn_re[166] = 16'h0000;   assign  wn_im[166] = 16'h0000;   // 166 -0.596  0.803
assign  wn_re[167] = 16'h0000;   assign  wn_im[167] = 16'h0000;   // 167 -0.576  0.818
assign  wn_re[168] = 16'h1319;   assign  wn_im[168] = 16'h98A4;   // 168 -0.556  0.831
assign  wn_re[169] = 16'h0000;   assign  wn_im[169] = 16'h0000;   // 169 -0.535  0.845
assign  wn_re[170] = 16'h0000;   assign  wn_im[170] = 16'h0000;   // 170 -0.514  0.858
assign  wn_re[171] = 16'hB648;   assign  wn_im[171] = 16'h02B2;   // 171 -0.493  0.870
assign  wn_re[172] = 16'h0000;   assign  wn_im[172] = 16'h0000;   // 172 -0.471  0.882
assign  wn_re[173] = 16'h0000;   assign  wn_im[173] = 16'h0000;   // 173 -0.450  0.893
assign  wn_re[174] = 16'hDFEC;   assign  wn_im[174] = 16'hEBD1;   // 174 -0.428  0.904
assign  wn_re[175] = 16'h0000;   assign  wn_im[175] = 16'h0000;   // 175 -0.405  0.914
assign  wn_re[176] = 16'h0000;   assign  wn_im[176] = 16'h0000;   // 176 -0.383  0.924
assign  wn_re[177] = 16'hF59E;   assign  wn_im[177] = 16'h4EDB;   // 177 -0.360  0.933
assign  wn_re[178] = 16'h0000;   assign  wn_im[178] = 16'h0000;   // 178 -0.337  0.942
assign  wn_re[179] = 16'h0000;   assign  wn_im[179] = 16'h0000;   // 179 -0.314  0.950
assign  wn_re[180] = 16'hF3A2;   assign  wn_im[180] = 16'h055B;   // 180 -0.290  0.957
assign  wn_re[181] = 16'h0000;   assign  wn_im[181] = 16'h0000;   // 181 -0.267  0.964
assign  wn_re[182] = 16'h0000;   assign  wn_im[182] = 16'h0000;   // 182 -0.243  0.970
assign  wn_re[183] = 16'h7D96;   assign  wn_im[183] = 16'hCEB2;   // 183 -0.219  0.976
assign  wn_re[184] = 16'h0000;   assign  wn_im[184] = 16'h0000;   // 184 -0.195  0.981
assign  wn_re[185] = 16'h0000;   assign  wn_im[185] = 16'h0000;   // 185 -0.171  0.985
assign  wn_re[186] = 16'hEF91;   assign  wn_im[186] = 16'h55FC;   // 186 -0.147  0.989
assign  wn_re[187] = 16'h0000;   assign  wn_im[187] = 16'h0000;   // 187 -0.122  0.992
assign  wn_re[188] = 16'h0000;   assign  wn_im[188] = 16'h0000;   // 188 -0.098  0.995
assign  wn_re[189] = 16'h6FB7;   assign  wn_im[189] = 16'h36B4;   // 189 -0.074  0.997
assign  wn_re[190] = 16'h0000;   assign  wn_im[190] = 16'h0000;   // 190 -0.049  0.999
assign  wn_re[191] = 16'h0000;   assign  wn_im[191] = 16'h0000;   // 191 -0.025  1.000
assign  wn_re[192] = 16'h0000;   assign  wn_im[192] = 16'h0000;   // 192 -0.000  1.000
assign  wn_re[193] = 16'h0000;   assign  wn_im[193] = 16'h0000;   // 193  0.025  1.000
assign  wn_re[194] = 16'h0000;   assign  wn_im[194] = 16'h0000;   // 194  0.049  0.999
assign  wn_re[195] = 16'h0000;   assign  wn_im[195] = 16'h0000;   // 195  0.074  0.997
assign  wn_re[196] = 16'h0000;   assign  wn_im[196] = 16'h0000;   // 196  0.098  0.995
assign  wn_re[197] = 16'h0000;   assign  wn_im[197] = 16'h0000;   // 197  0.122  0.992
assign  wn_re[198] = 16'h0000;   assign  wn_im[198] = 16'h0000;   // 198  0.147  0.989
assign  wn_re[199] = 16'h0000;   assign  wn_im[199] = 16'h0000;   // 199  0.171  0.985
assign  wn_re[200] = 16'h0000;   assign  wn_im[200] = 16'h0000;   // 200  0.195  0.981
assign  wn_re[201] = 16'h0000;   assign  wn_im[201] = 16'h0000;   // 201  0.219  0.976
assign  wn_re[202] = 16'h0000;   assign  wn_im[202] = 16'h0000;   // 202  0.243  0.970
assign  wn_re[203] = 16'h0000;   assign  wn_im[203] = 16'h0000;   // 203  0.267  0.964
assign  wn_re[204] = 16'h0000;   assign  wn_im[204] = 16'h0000;   // 204  0.290  0.957
assign  wn_re[205] = 16'h0000;   assign  wn_im[205] = 16'h0000;   // 205  0.314  0.950
assign  wn_re[206] = 16'h0000;   assign  wn_im[206] = 16'h0000;   // 206  0.337  0.942
assign  wn_re[207] = 16'h0000;   assign  wn_im[207] = 16'h0000;   // 207  0.360  0.933
assign  wn_re[208] = 16'h0000;   assign  wn_im[208] = 16'h0000;   // 208  0.383  0.924
assign  wn_re[209] = 16'h0000;   assign  wn_im[209] = 16'h0000;   // 209  0.405  0.914
assign  wn_re[210] = 16'h0000;   assign  wn_im[210] = 16'h0000;   // 210  0.428  0.904
assign  wn_re[211] = 16'h0000;   assign  wn_im[211] = 16'h0000;   // 211  0.450  0.893
assign  wn_re[212] = 16'h0000;   assign  wn_im[212] = 16'h0000;   // 212  0.471  0.882
assign  wn_re[213] = 16'h0000;   assign  wn_im[213] = 16'h0000;   // 213  0.493  0.870
assign  wn_re[214] = 16'h0000;   assign  wn_im[214] = 16'h0000;   // 214  0.514  0.858
assign  wn_re[215] = 16'h0000;   assign  wn_im[215] = 16'h0000;   // 215  0.535  0.845
assign  wn_re[216] = 16'h0000;   assign  wn_im[216] = 16'h0000;   // 216  0.556  0.831
assign  wn_re[217] = 16'h0000;   assign  wn_im[217] = 16'h0000;   // 217  0.576  0.818
assign  wn_re[218] = 16'h0000;   assign  wn_im[218] = 16'h0000;   // 218  0.596  0.803
assign  wn_re[219] = 16'h0000;   assign  wn_im[219] = 16'h0000;   // 219  0.615  0.788
assign  wn_re[220] = 16'h0000;   assign  wn_im[220] = 16'h0000;   // 220  0.634  0.773
assign  wn_re[221] = 16'h0000;   assign  wn_im[221] = 16'h0000;   // 221  0.653  0.757
assign  wn_re[222] = 16'h0000;   assign  wn_im[222] = 16'h0000;   // 222  0.672  0.741
assign  wn_re[223] = 16'h0000;   assign  wn_im[223] = 16'h0000;   // 223  0.690  0.724
assign  wn_re[224] = 16'h0000;   assign  wn_im[224] = 16'h0000;   // 224  0.707  0.707
assign  wn_re[225] = 16'h0000;   assign  wn_im[225] = 16'h0000;   // 225  0.724  0.690
assign  wn_re[226] = 16'h0000;   assign  wn_im[226] = 16'h0000;   // 226  0.741  0.672
assign  wn_re[227] = 16'h0000;   assign  wn_im[227] = 16'h0000;   // 227  0.757  0.653
assign  wn_re[228] = 16'h0000;   assign  wn_im[228] = 16'h0000;   // 228  0.773  0.634
assign  wn_re[229] = 16'h0000;   assign  wn_im[229] = 16'h0000;   // 229  0.788  0.615
assign  wn_re[230] = 16'h0000;   assign  wn_im[230] = 16'h0000;   // 230  0.803  0.596
assign  wn_re[231] = 16'h0000;   assign  wn_im[231] = 16'h0000;   // 231  0.818  0.576
assign  wn_re[232] = 16'h0000;   assign  wn_im[232] = 16'h0000;   // 232  0.831  0.556
assign  wn_re[233] = 16'h0000;   assign  wn_im[233] = 16'h0000;   // 233  0.845  0.535
assign  wn_re[234] = 16'h0000;   assign  wn_im[234] = 16'h0000;   // 234  0.858  0.514
assign  wn_re[235] = 16'h0000;   assign  wn_im[235] = 16'h0000;   // 235  0.870  0.493
assign  wn_re[236] = 16'h0000;   assign  wn_im[236] = 16'h0000;   // 236  0.882  0.471
assign  wn_re[237] = 16'h0000;   assign  wn_im[237] = 16'h0000;   // 237  0.893  0.450
assign  wn_re[238] = 16'h0000;   assign  wn_im[238] = 16'h0000;   // 238  0.904  0.428
assign  wn_re[239] = 16'h0000;   assign  wn_im[239] = 16'h0000;   // 239  0.914  0.405
assign  wn_re[240] = 16'h0000;   assign  wn_im[240] = 16'h0000;   // 240  0.924  0.383
assign  wn_re[241] = 16'h0000;   assign  wn_im[241] = 16'h0000;   // 241  0.933  0.360
assign  wn_re[242] = 16'h0000;   assign  wn_im[242] = 16'h0000;   // 242  0.942  0.337
assign  wn_re[243] = 16'h0000;   assign  wn_im[243] = 16'h0000;   // 243  0.950  0.314
assign  wn_re[244] = 16'h0000;   assign  wn_im[244] = 16'h0000;   // 244  0.957  0.290
assign  wn_re[245] = 16'h0000;   assign  wn_im[245] = 16'h0000;   // 245  0.964  0.267
assign  wn_re[246] = 16'h0000;   assign  wn_im[246] = 16'h0000;   // 246  0.970  0.243
assign  wn_re[247] = 16'h0000;   assign  wn_im[247] = 16'h0000;   // 247  0.976  0.219
assign  wn_re[248] = 16'h0000;   assign  wn_im[248] = 16'h0000;   // 248  0.981  0.195
assign  wn_re[249] = 16'h0000;   assign  wn_im[249] = 16'h0000;   // 249  0.985  0.171
assign  wn_re[250] = 16'h0000;   assign  wn_im[250] = 16'h0000;   // 250  0.989  0.147
assign  wn_re[251] = 16'h0000;   assign  wn_im[251] = 16'h0000;   // 251  0.992  0.122
assign  wn_re[252] = 16'h0000;   assign  wn_im[252] = 16'h0000;   // 252  0.995  0.098
assign  wn_re[253] = 16'h0000;   assign  wn_im[253] = 16'h0000;   // 253  0.997  0.074
assign  wn_re[254] = 16'h0000;   assign  wn_im[254] = 16'h0000;   // 254  0.999  0.049
assign  wn_re[255] = 16'h0000;   assign  wn_im[255] = 16'h0000;   // 255  1.000  0.025

endmodule
