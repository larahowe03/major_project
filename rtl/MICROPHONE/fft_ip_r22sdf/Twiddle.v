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

wire[15:0]  wn_re[0:511];  //  Twiddle Table (Real)
wire[15:0]  wn_im[0:511];  //  Twiddle Table (Imag)
wire[15:0]  mx_re;          //  Multiplexer output (Real)
wire[15:0]  mx_im;          //  Multiplexer output (Imag)
reg [15:0]  ff_re;          //  Register output (Real)
reg [15:0]  ff_im;          //  Register output (Imag)

assign  mx_re = wn_re[addr];
assign  mx_im = wn_im[addr];

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
assign  wn_re[ 0] = 32'h00000000;   assign  wn_im[ 0] = 32'h00000000;   //  0  1.000 -0.000
assign  wn_re[ 1] = 32'h7FF62182;   assign  wn_im[ 1] = 32'hFCDBD541;   //  1  1.000 -0.025
assign  wn_re[ 2] = 32'h7FD8878E;   assign  wn_im[ 2] = 32'hF9B82684;   //  2  0.999 -0.049
assign  wn_re[ 3] = 32'h7FA736B4;   assign  wn_im[ 3] = 32'hF6956FB7;   //  3  0.997 -0.074
assign  wn_re[ 4] = 32'h7F62368F;   assign  wn_im[ 4] = 32'hF3742CA2;   //  4  0.995 -0.098
assign  wn_re[ 5] = 32'h7F0991C4;   assign  wn_im[ 5] = 32'hF054D8D5;   //  5  0.992 -0.122
assign  wn_re[ 6] = 32'h7E9D55FC;   assign  wn_im[ 6] = 32'hED37EF91;   //  6  0.989 -0.147
assign  wn_re[ 7] = 32'h7E1D93EA;   assign  wn_im[ 7] = 32'hEA1DEBBB;   //  7  0.985 -0.171
assign  wn_re[ 8] = 32'h7D8A5F40;   assign  wn_im[ 8] = 32'hE70747C4;   //  8  0.981 -0.195
assign  wn_re[ 9] = 32'h7CE3CEB2;   assign  wn_im[ 9] = 32'hE3F47D96;   //  9  0.976 -0.219
assign  wn_re[10] = 32'h7C29FBEE;   assign  wn_im[10] = 32'hE0E60685;   // 10  0.970 -0.243
assign  wn_re[11] = 32'h7B5D039E;   assign  wn_im[11] = 32'hDDDC5B3B;   // 11  0.964 -0.267
assign  wn_re[12] = 32'h7A7D055B;   assign  wn_im[12] = 32'hDAD7F3A2;   // 12  0.957 -0.290
assign  wn_re[13] = 32'h798A23B1;   assign  wn_im[13] = 32'hD7D946D8;   // 13  0.950 -0.314
assign  wn_re[14] = 32'h78848414;   assign  wn_im[14] = 32'hD4E0CB15;   // 14  0.942 -0.337
assign  wn_re[15] = 32'h776C4EDB;   assign  wn_im[15] = 32'hD1EEF59E;   // 15  0.933 -0.360
assign  wn_re[16] = 32'h7641AF3D;   assign  wn_im[16] = 32'hCF043AB3;   // 16  0.924 -0.383
assign  wn_re[17] = 32'h7504D345;   assign  wn_im[17] = 32'hCC210D79;   // 17  0.914 -0.405
assign  wn_re[18] = 32'h73B5EBD1;   assign  wn_im[18] = 32'hC945DFEC;   // 18  0.904 -0.428
assign  wn_re[19] = 32'h72552C85;   assign  wn_im[19] = 32'hC67322CE;   // 19  0.893 -0.450
assign  wn_re[20] = 32'h70E2CBC6;   assign  wn_im[20] = 32'hC3A94590;   // 20  0.882 -0.471
assign  wn_re[21] = 32'h6F5F02B2;   assign  wn_im[21] = 32'hC0E8B648;   // 21  0.870 -0.493
assign  wn_re[22] = 32'h6DCA0D14;   assign  wn_im[22] = 32'hBE31E19B;   // 22  0.858 -0.514
assign  wn_re[23] = 32'h6C242960;   assign  wn_im[23] = 32'hBB8532B0;   // 23  0.845 -0.535
assign  wn_re[24] = 32'h6A6D98A4;   assign  wn_im[24] = 32'hB8E31319;   // 24  0.831 -0.556
assign  wn_re[25] = 32'h68A69E81;   assign  wn_im[25] = 32'hB64BEACD;   // 25  0.818 -0.576
assign  wn_re[26] = 32'h66CF8120;   assign  wn_im[26] = 32'hB3C0200C;   // 26  0.803 -0.596
assign  wn_re[27] = 32'h64E88926;   assign  wn_im[27] = 32'hB140175B;   // 27  0.788 -0.615
assign  wn_re[28] = 32'h62F201AC;   assign  wn_im[28] = 32'hAECC336C;   // 28  0.773 -0.634
assign  wn_re[29] = 32'h60EC3830;   assign  wn_im[29] = 32'hAC64D510;   // 29  0.757 -0.653
assign  wn_re[30] = 32'h5ED77C8A;   assign  wn_im[30] = 32'hAA0A5B2E;   // 30  0.741 -0.672
assign  wn_re[31] = 32'h5CB420E0;   assign  wn_im[31] = 32'hA7BD22AC;   // 31  0.724 -0.690
assign  wn_re[32] = 32'h5A82799A;   assign  wn_im[32] = 32'hA57D8666;   // 32  0.707 -0.707
assign  wn_re[33] = 32'h5842DD54;   assign  wn_im[33] = 32'hA34BDF20;   // 33  0.690 -0.724
assign  wn_re[34] = 32'h55F5A4D2;   assign  wn_im[34] = 32'hA1288376;   // 34  0.672 -0.741
assign  wn_re[35] = 32'h539B2AF0;   assign  wn_im[35] = 32'h9F13C7D0;   // 35  0.653 -0.757
assign  wn_re[36] = 32'h5133CC94;   assign  wn_im[36] = 32'h9D0DFE54;   // 36  0.634 -0.773
assign  wn_re[37] = 32'h4EBFE8A5;   assign  wn_im[37] = 32'h9B1776DA;   // 37  0.615 -0.788
assign  wn_re[38] = 32'h4C3FDFF4;   assign  wn_im[38] = 32'h99307EE0;   // 38  0.596 -0.803
assign  wn_re[39] = 32'h49B41533;   assign  wn_im[39] = 32'h9759617F;   // 39  0.576 -0.818
assign  wn_re[40] = 32'h471CECE7;   assign  wn_im[40] = 32'h9592675C;   // 40  0.556 -0.831
assign  wn_re[41] = 32'h447ACD50;   assign  wn_im[41] = 32'h93DBD6A0;   // 41  0.535 -0.845
assign  wn_re[42] = 32'h41CE1E65;   assign  wn_im[42] = 32'h9235F2EC;   // 42  0.514 -0.858
assign  wn_re[43] = 32'h3F1749B8;   assign  wn_im[43] = 32'h90A0FD4E;   // 43  0.493 -0.870
assign  wn_re[44] = 32'h3C56BA70;   assign  wn_im[44] = 32'h8F1D343A;   // 44  0.471 -0.882
assign  wn_re[45] = 32'h398CDD32;   assign  wn_im[45] = 32'h8DAAD37B;   // 45  0.450 -0.893
assign  wn_re[46] = 32'h36BA2014;   assign  wn_im[46] = 32'h8C4A142F;   // 46  0.428 -0.904
assign  wn_re[47] = 32'h33DEF287;   assign  wn_im[47] = 32'h8AFB2CBB;   // 47  0.405 -0.914
assign  wn_re[48] = 32'h30FBC54D;   assign  wn_im[48] = 32'h89BE50C3;   // 48  0.383 -0.924
assign  wn_re[49] = 32'h2E110A62;   assign  wn_im[49] = 32'h8893B125;   // 49  0.360 -0.933
assign  wn_re[50] = 32'h2B1F34EB;   assign  wn_im[50] = 32'h877B7BEC;   // 50  0.337 -0.942
assign  wn_re[51] = 32'h2826B928;   assign  wn_im[51] = 32'h8675DC4F;   // 51  0.314 -0.950
assign  wn_re[52] = 32'h25280C5E;   assign  wn_im[52] = 32'h8582FAA5;   // 52  0.290 -0.957
assign  wn_re[53] = 32'h2223A4C5;   assign  wn_im[53] = 32'h84A2FC62;   // 53  0.267 -0.964
assign  wn_re[54] = 32'h1F19F97B;   assign  wn_im[54] = 32'h83D60412;   // 54  0.243 -0.970
assign  wn_re[55] = 32'h1C0B826A;   assign  wn_im[55] = 32'h831C314E;   // 55  0.219 -0.976
assign  wn_re[56] = 32'h18F8B83C;   assign  wn_im[56] = 32'h8275A0C0;   // 56  0.195 -0.981
assign  wn_re[57] = 32'h15E21445;   assign  wn_im[57] = 32'h81E26C16;   // 57  0.171 -0.985
assign  wn_re[58] = 32'h12C8106F;   assign  wn_im[58] = 32'h8162AA04;   // 58  0.147 -0.989
assign  wn_re[59] = 32'h0FAB272B;   assign  wn_im[59] = 32'h80F66E3C;   // 59  0.122 -0.992
assign  wn_re[60] = 32'h0C8BD35E;   assign  wn_im[60] = 32'h809DC971;   // 60  0.098 -0.995
assign  wn_re[61] = 32'h096A9049;   assign  wn_im[61] = 32'h8058C94C;   // 61  0.074 -0.997
assign  wn_re[62] = 32'h0647D97C;   assign  wn_im[62] = 32'h80277872;   // 62  0.049 -0.999
assign  wn_re[63] = 32'h03242ABF;   assign  wn_im[63] = 32'h8009DE7E;   // 63  0.025 -1.000
assign  wn_re[64] = 32'h00000000;   assign  wn_im[64] = 32'h80000000;   // 64  0.000 -1.000
assign  wn_re[65] = 32'hxxxxxxxx;   assign  wn_im[65] = 32'hxxxxxxxx;   // 65 -0.025 -1.000
assign  wn_re[66] = 32'hF9B82684;   assign  wn_im[66] = 32'h80277872;   // 66 -0.049 -0.999
assign  wn_re[67] = 32'hxxxxxxxx;   assign  wn_im[67] = 32'hxxxxxxxx;   // 67 -0.074 -0.997
assign  wn_re[68] = 32'hF3742CA2;   assign  wn_im[68] = 32'h809DC971;   // 68 -0.098 -0.995
assign  wn_re[69] = 32'hF054D8D5;   assign  wn_im[69] = 32'h80F66E3C;   // 69 -0.122 -0.992
assign  wn_re[70] = 32'hED37EF91;   assign  wn_im[70] = 32'h8162AA04;   // 70 -0.147 -0.989
assign  wn_re[71] = 32'hxxxxxxxx;   assign  wn_im[71] = 32'hxxxxxxxx;   // 71 -0.171 -0.985
assign  wn_re[72] = 32'hE70747C4;   assign  wn_im[72] = 32'h8275A0C0;   // 72 -0.195 -0.981
assign  wn_re[73] = 32'hxxxxxxxx;   assign  wn_im[73] = 32'hxxxxxxxx;   // 73 -0.219 -0.976
assign  wn_re[74] = 32'hE0E60685;   assign  wn_im[74] = 32'h83D60412;   // 74 -0.243 -0.970
assign  wn_re[75] = 32'hDDDC5B3B;   assign  wn_im[75] = 32'h84A2FC62;   // 75 -0.267 -0.964
assign  wn_re[76] = 32'hDAD7F3A2;   assign  wn_im[76] = 32'h8582FAA5;   // 76 -0.290 -0.957
assign  wn_re[77] = 32'hxxxxxxxx;   assign  wn_im[77] = 32'hxxxxxxxx;   // 77 -0.314 -0.950
assign  wn_re[78] = 32'hD4E0CB15;   assign  wn_im[78] = 32'h877B7BEC;   // 78 -0.337 -0.942
assign  wn_re[79] = 32'hxxxxxxxx;   assign  wn_im[79] = 32'hxxxxxxxx;   // 79 -0.360 -0.933
assign  wn_re[80] = 32'hCF043AB3;   assign  wn_im[80] = 32'h89BE50C3;   // 80 -0.383 -0.924
assign  wn_re[81] = 32'hCC210D79;   assign  wn_im[81] = 32'h8AFB2CBB;   // 81 -0.405 -0.914
assign  wn_re[82] = 32'hC945DFEC;   assign  wn_im[82] = 32'h8C4A142F;   // 82 -0.428 -0.904
assign  wn_re[83] = 32'hxxxxxxxx;   assign  wn_im[83] = 32'hxxxxxxxx;   // 83 -0.450 -0.893
assign  wn_re[84] = 32'hC3A94590;   assign  wn_im[84] = 32'h8F1D343A;   // 84 -0.471 -0.882
assign  wn_re[85] = 32'hxxxxxxxx;   assign  wn_im[85] = 32'hxxxxxxxx;   // 85 -0.493 -0.870
assign  wn_re[86] = 32'hBE31E19B;   assign  wn_im[86] = 32'h9235F2EC;   // 86 -0.514 -0.858
assign  wn_re[87] = 32'hBB8532B0;   assign  wn_im[87] = 32'h93DBD6A0;   // 87 -0.535 -0.845
assign  wn_re[88] = 32'hB8E31319;   assign  wn_im[88] = 32'h9592675C;   // 88 -0.556 -0.831
assign  wn_re[89] = 32'hxxxxxxxx;   assign  wn_im[89] = 32'hxxxxxxxx;   // 89 -0.576 -0.818
assign  wn_re[90] = 32'hB3C0200C;   assign  wn_im[90] = 32'h99307EE0;   // 90 -0.596 -0.803
assign  wn_re[91] = 32'hxxxxxxxx;   assign  wn_im[91] = 32'hxxxxxxxx;   // 91 -0.615 -0.788
assign  wn_re[92] = 32'hAECC336C;   assign  wn_im[92] = 32'h9D0DFE54;   // 92 -0.634 -0.773
assign  wn_re[93] = 32'hAC64D510;   assign  wn_im[93] = 32'h9F13C7D0;   // 93 -0.653 -0.757
assign  wn_re[94] = 32'hAA0A5B2E;   assign  wn_im[94] = 32'hA1288376;   // 94 -0.672 -0.741
assign  wn_re[95] = 32'hxxxxxxxx;   assign  wn_im[95] = 32'hxxxxxxxx;   // 95 -0.690 -0.724
assign  wn_re[96] = 32'hA57D8666;   assign  wn_im[96] = 32'hA57D8666;   // 96 -0.707 -0.707
assign  wn_re[97] = 32'hxxxxxxxx;   assign  wn_im[97] = 32'hxxxxxxxx;   // 97 -0.724 -0.690
assign  wn_re[98] = 32'hA1288376;   assign  wn_im[98] = 32'hAA0A5B2E;   // 98 -0.741 -0.672
assign  wn_re[99] = 32'h9F13C7D0;   assign  wn_im[99] = 32'hAC64D510;   // 99 -0.757 -0.653
assign  wn_re[100] = 32'h9D0DFE54;   assign  wn_im[100] = 32'hAECC336C;   // 100 -0.773 -0.634
assign  wn_re[101] = 32'hxxxxxxxx;   assign  wn_im[101] = 32'hxxxxxxxx;   // 101 -0.788 -0.615
assign  wn_re[102] = 32'h99307EE0;   assign  wn_im[102] = 32'hB3C0200C;   // 102 -0.803 -0.596
assign  wn_re[103] = 32'hxxxxxxxx;   assign  wn_im[103] = 32'hxxxxxxxx;   // 103 -0.818 -0.576
assign  wn_re[104] = 32'h9592675C;   assign  wn_im[104] = 32'hB8E31319;   // 104 -0.831 -0.556
assign  wn_re[105] = 32'h93DBD6A0;   assign  wn_im[105] = 32'hBB8532B0;   // 105 -0.845 -0.535
assign  wn_re[106] = 32'h9235F2EC;   assign  wn_im[106] = 32'hBE31E19B;   // 106 -0.858 -0.514
assign  wn_re[107] = 32'hxxxxxxxx;   assign  wn_im[107] = 32'hxxxxxxxx;   // 107 -0.870 -0.493
assign  wn_re[108] = 32'h8F1D343A;   assign  wn_im[108] = 32'hC3A94590;   // 108 -0.882 -0.471
assign  wn_re[109] = 32'hxxxxxxxx;   assign  wn_im[109] = 32'hxxxxxxxx;   // 109 -0.893 -0.450
assign  wn_re[110] = 32'h8C4A142F;   assign  wn_im[110] = 32'hC945DFEC;   // 110 -0.904 -0.428
assign  wn_re[111] = 32'h8AFB2CBB;   assign  wn_im[111] = 32'hCC210D79;   // 111 -0.914 -0.405
assign  wn_re[112] = 32'h89BE50C3;   assign  wn_im[112] = 32'hCF043AB3;   // 112 -0.924 -0.383
assign  wn_re[113] = 32'hxxxxxxxx;   assign  wn_im[113] = 32'hxxxxxxxx;   // 113 -0.933 -0.360
assign  wn_re[114] = 32'h877B7BEC;   assign  wn_im[114] = 32'hD4E0CB15;   // 114 -0.942 -0.337
assign  wn_re[115] = 32'hxxxxxxxx;   assign  wn_im[115] = 32'hxxxxxxxx;   // 115 -0.950 -0.314
assign  wn_re[116] = 32'h8582FAA5;   assign  wn_im[116] = 32'hDAD7F3A2;   // 116 -0.957 -0.290
assign  wn_re[117] = 32'h84A2FC62;   assign  wn_im[117] = 32'hDDDC5B3B;   // 117 -0.964 -0.267
assign  wn_re[118] = 32'h83D60412;   assign  wn_im[118] = 32'hE0E60685;   // 118 -0.970 -0.243
assign  wn_re[119] = 32'hxxxxxxxx;   assign  wn_im[119] = 32'hxxxxxxxx;   // 119 -0.976 -0.219
assign  wn_re[120] = 32'h8275A0C0;   assign  wn_im[120] = 32'hE70747C4;   // 120 -0.981 -0.195
assign  wn_re[121] = 32'hxxxxxxxx;   assign  wn_im[121] = 32'hxxxxxxxx;   // 121 -0.985 -0.171
assign  wn_re[122] = 32'h8162AA04;   assign  wn_im[122] = 32'hED37EF91;   // 122 -0.989 -0.147
assign  wn_re[123] = 32'h80F66E3C;   assign  wn_im[123] = 32'hF054D8D5;   // 123 -0.992 -0.122
assign  wn_re[124] = 32'h809DC971;   assign  wn_im[124] = 32'hF3742CA2;   // 124 -0.995 -0.098
assign  wn_re[125] = 32'hxxxxxxxx;   assign  wn_im[125] = 32'hxxxxxxxx;   // 125 -0.997 -0.074
assign  wn_re[126] = 32'h80277872;   assign  wn_im[126] = 32'hF9B82684;   // 126 -0.999 -0.049
assign  wn_re[127] = 32'hxxxxxxxx;   assign  wn_im[127] = 32'hxxxxxxxx;   // 127 -1.000 -0.025
assign  wn_re[128] = 32'hxxxxxxxx;   assign  wn_im[128] = 32'hxxxxxxxx;   // 128 -1.000 -0.000
assign  wn_re[129] = 32'h8009DE7E;   assign  wn_im[129] = 32'h03242ABF;   // 129 -1.000  0.025
assign  wn_re[130] = 32'hxxxxxxxx;   assign  wn_im[130] = 32'hxxxxxxxx;   // 130 -0.999  0.049
assign  wn_re[131] = 32'hxxxxxxxx;   assign  wn_im[131] = 32'hxxxxxxxx;   // 131 -0.997  0.074
assign  wn_re[132] = 32'h809DC971;   assign  wn_im[132] = 32'h0C8BD35E;   // 132 -0.995  0.098
assign  wn_re[133] = 32'hxxxxxxxx;   assign  wn_im[133] = 32'hxxxxxxxx;   // 133 -0.992  0.122
assign  wn_re[134] = 32'hxxxxxxxx;   assign  wn_im[134] = 32'hxxxxxxxx;   // 134 -0.989  0.147
assign  wn_re[135] = 32'h81E26C16;   assign  wn_im[135] = 32'h15E21445;   // 135 -0.985  0.171
assign  wn_re[136] = 32'hxxxxxxxx;   assign  wn_im[136] = 32'hxxxxxxxx;   // 136 -0.981  0.195
assign  wn_re[137] = 32'hxxxxxxxx;   assign  wn_im[137] = 32'hxxxxxxxx;   // 137 -0.976  0.219
assign  wn_re[138] = 32'h83D60412;   assign  wn_im[138] = 32'h1F19F97B;   // 138 -0.970  0.243
assign  wn_re[139] = 32'hxxxxxxxx;   assign  wn_im[139] = 32'hxxxxxxxx;   // 139 -0.964  0.267
assign  wn_re[140] = 32'hxxxxxxxx;   assign  wn_im[140] = 32'hxxxxxxxx;   // 140 -0.957  0.290
assign  wn_re[141] = 32'h8675DC4F;   assign  wn_im[141] = 32'h2826B928;   // 141 -0.950  0.314
assign  wn_re[142] = 32'hxxxxxxxx;   assign  wn_im[142] = 32'hxxxxxxxx;   // 142 -0.942  0.337
assign  wn_re[143] = 32'hxxxxxxxx;   assign  wn_im[143] = 32'hxxxxxxxx;   // 143 -0.933  0.360
assign  wn_re[144] = 32'h89BE50C3;   assign  wn_im[144] = 32'h30FBC54D;   // 144 -0.924  0.383
assign  wn_re[145] = 32'hxxxxxxxx;   assign  wn_im[145] = 32'hxxxxxxxx;   // 145 -0.914  0.405
assign  wn_re[146] = 32'hxxxxxxxx;   assign  wn_im[146] = 32'hxxxxxxxx;   // 146 -0.904  0.428
assign  wn_re[147] = 32'h8DAAD37B;   assign  wn_im[147] = 32'h398CDD32;   // 147 -0.893  0.450
assign  wn_re[148] = 32'hxxxxxxxx;   assign  wn_im[148] = 32'hxxxxxxxx;   // 148 -0.882  0.471
assign  wn_re[149] = 32'hxxxxxxxx;   assign  wn_im[149] = 32'hxxxxxxxx;   // 149 -0.870  0.493
assign  wn_re[150] = 32'h9235F2EC;   assign  wn_im[150] = 32'h41CE1E65;   // 150 -0.858  0.514
assign  wn_re[151] = 32'hxxxxxxxx;   assign  wn_im[151] = 32'hxxxxxxxx;   // 151 -0.845  0.535
assign  wn_re[152] = 32'hxxxxxxxx;   assign  wn_im[152] = 32'hxxxxxxxx;   // 152 -0.831  0.556
assign  wn_re[153] = 32'h9759617F;   assign  wn_im[153] = 32'h49B41533;   // 153 -0.818  0.576
assign  wn_re[154] = 32'hxxxxxxxx;   assign  wn_im[154] = 32'hxxxxxxxx;   // 154 -0.803  0.596
assign  wn_re[155] = 32'hxxxxxxxx;   assign  wn_im[155] = 32'hxxxxxxxx;   // 155 -0.788  0.615
assign  wn_re[156] = 32'h9D0DFE54;   assign  wn_im[156] = 32'h5133CC94;   // 156 -0.773  0.634
assign  wn_re[157] = 32'hxxxxxxxx;   assign  wn_im[157] = 32'hxxxxxxxx;   // 157 -0.757  0.653
assign  wn_re[158] = 32'hxxxxxxxx;   assign  wn_im[158] = 32'hxxxxxxxx;   // 158 -0.741  0.672
assign  wn_re[159] = 32'hA34BDF20;   assign  wn_im[159] = 32'h5842DD54;   // 159 -0.724  0.690
assign  wn_re[160] = 32'hxxxxxxxx;   assign  wn_im[160] = 32'hxxxxxxxx;   // 160 -0.707  0.707
assign  wn_re[161] = 32'hxxxxxxxx;   assign  wn_im[161] = 32'hxxxxxxxx;   // 161 -0.690  0.724
assign  wn_re[162] = 32'hAA0A5B2E;   assign  wn_im[162] = 32'h5ED77C8A;   // 162 -0.672  0.741
assign  wn_re[163] = 32'hxxxxxxxx;   assign  wn_im[163] = 32'hxxxxxxxx;   // 163 -0.653  0.757
assign  wn_re[164] = 32'hxxxxxxxx;   assign  wn_im[164] = 32'hxxxxxxxx;   // 164 -0.634  0.773
assign  wn_re[165] = 32'hB140175B;   assign  wn_im[165] = 32'h64E88926;   // 165 -0.615  0.788
assign  wn_re[166] = 32'hxxxxxxxx;   assign  wn_im[166] = 32'hxxxxxxxx;   // 166 -0.596  0.803
assign  wn_re[167] = 32'hxxxxxxxx;   assign  wn_im[167] = 32'hxxxxxxxx;   // 167 -0.576  0.818
assign  wn_re[168] = 32'hB8E31319;   assign  wn_im[168] = 32'h6A6D98A4;   // 168 -0.556  0.831
assign  wn_re[169] = 32'hxxxxxxxx;   assign  wn_im[169] = 32'hxxxxxxxx;   // 169 -0.535  0.845
assign  wn_re[170] = 32'hxxxxxxxx;   assign  wn_im[170] = 32'hxxxxxxxx;   // 170 -0.514  0.858
assign  wn_re[171] = 32'hC0E8B648;   assign  wn_im[171] = 32'h6F5F02B2;   // 171 -0.493  0.870
assign  wn_re[172] = 32'hxxxxxxxx;   assign  wn_im[172] = 32'hxxxxxxxx;   // 172 -0.471  0.882
assign  wn_re[173] = 32'hxxxxxxxx;   assign  wn_im[173] = 32'hxxxxxxxx;   // 173 -0.450  0.893
assign  wn_re[174] = 32'hC945DFEC;   assign  wn_im[174] = 32'h73B5EBD1;   // 174 -0.428  0.904
assign  wn_re[175] = 32'hxxxxxxxx;   assign  wn_im[175] = 32'hxxxxxxxx;   // 175 -0.405  0.914
assign  wn_re[176] = 32'hxxxxxxxx;   assign  wn_im[176] = 32'hxxxxxxxx;   // 176 -0.383  0.924
assign  wn_re[177] = 32'hD1EEF59E;   assign  wn_im[177] = 32'h776C4EDB;   // 177 -0.360  0.933
assign  wn_re[178] = 32'hxxxxxxxx;   assign  wn_im[178] = 32'hxxxxxxxx;   // 178 -0.337  0.942
assign  wn_re[179] = 32'hxxxxxxxx;   assign  wn_im[179] = 32'hxxxxxxxx;   // 179 -0.314  0.950
assign  wn_re[180] = 32'hDAD7F3A2;   assign  wn_im[180] = 32'h7A7D055B;   // 180 -0.290  0.957
assign  wn_re[181] = 32'hxxxxxxxx;   assign  wn_im[181] = 32'hxxxxxxxx;   // 181 -0.267  0.964
assign  wn_re[182] = 32'hxxxxxxxx;   assign  wn_im[182] = 32'hxxxxxxxx;   // 182 -0.243  0.970
assign  wn_re[183] = 32'hE3F47D96;   assign  wn_im[183] = 32'h7CE3CEB2;   // 183 -0.219  0.976
assign  wn_re[184] = 32'hxxxxxxxx;   assign  wn_im[184] = 32'hxxxxxxxx;   // 184 -0.195  0.981
assign  wn_re[185] = 32'hxxxxxxxx;   assign  wn_im[185] = 32'hxxxxxxxx;   // 185 -0.171  0.985
assign  wn_re[186] = 32'hED37EF91;   assign  wn_im[186] = 32'h7E9D55FC;   // 186 -0.147  0.989
assign  wn_re[187] = 32'hxxxxxxxx;   assign  wn_im[187] = 32'hxxxxxxxx;   // 187 -0.122  0.992
assign  wn_re[188] = 32'hxxxxxxxx;   assign  wn_im[188] = 32'hxxxxxxxx;   // 188 -0.098  0.995
assign  wn_re[189] = 32'hF6956FB7;   assign  wn_im[189] = 32'h7FA736B4;   // 189 -0.074  0.997
assign  wn_re[190] = 32'hxxxxxxxx;   assign  wn_im[190] = 32'hxxxxxxxx;   // 190 -0.049  0.999
assign  wn_re[191] = 32'hxxxxxxxx;   assign  wn_im[191] = 32'hxxxxxxxx;   // 191 -0.025  1.000
assign  wn_re[192] = 32'hxxxxxxxx;   assign  wn_im[192] = 32'hxxxxxxxx;   // 192 -0.000  1.000
assign  wn_re[193] = 32'hxxxxxxxx;   assign  wn_im[193] = 32'hxxxxxxxx;   // 193  0.025  1.000
assign  wn_re[194] = 32'hxxxxxxxx;   assign  wn_im[194] = 32'hxxxxxxxx;   // 194  0.049  0.999
assign  wn_re[195] = 32'hxxxxxxxx;   assign  wn_im[195] = 32'hxxxxxxxx;   // 195  0.074  0.997
assign  wn_re[196] = 32'hxxxxxxxx;   assign  wn_im[196] = 32'hxxxxxxxx;   // 196  0.098  0.995
assign  wn_re[197] = 32'hxxxxxxxx;   assign  wn_im[197] = 32'hxxxxxxxx;   // 197  0.122  0.992
assign  wn_re[198] = 32'hxxxxxxxx;   assign  wn_im[198] = 32'hxxxxxxxx;   // 198  0.147  0.989
assign  wn_re[199] = 32'hxxxxxxxx;   assign  wn_im[199] = 32'hxxxxxxxx;   // 199  0.171  0.985
assign  wn_re[200] = 32'hxxxxxxxx;   assign  wn_im[200] = 32'hxxxxxxxx;   // 200  0.195  0.981
assign  wn_re[201] = 32'hxxxxxxxx;   assign  wn_im[201] = 32'hxxxxxxxx;   // 201  0.219  0.976
assign  wn_re[202] = 32'hxxxxxxxx;   assign  wn_im[202] = 32'hxxxxxxxx;   // 202  0.243  0.970
assign  wn_re[203] = 32'hxxxxxxxx;   assign  wn_im[203] = 32'hxxxxxxxx;   // 203  0.267  0.964
assign  wn_re[204] = 32'hxxxxxxxx;   assign  wn_im[204] = 32'hxxxxxxxx;   // 204  0.290  0.957
assign  wn_re[205] = 32'hxxxxxxxx;   assign  wn_im[205] = 32'hxxxxxxxx;   // 205  0.314  0.950
assign  wn_re[206] = 32'hxxxxxxxx;   assign  wn_im[206] = 32'hxxxxxxxx;   // 206  0.337  0.942
assign  wn_re[207] = 32'hxxxxxxxx;   assign  wn_im[207] = 32'hxxxxxxxx;   // 207  0.360  0.933
assign  wn_re[208] = 32'hxxxxxxxx;   assign  wn_im[208] = 32'hxxxxxxxx;   // 208  0.383  0.924
assign  wn_re[209] = 32'hxxxxxxxx;   assign  wn_im[209] = 32'hxxxxxxxx;   // 209  0.405  0.914
assign  wn_re[210] = 32'hxxxxxxxx;   assign  wn_im[210] = 32'hxxxxxxxx;   // 210  0.428  0.904
assign  wn_re[211] = 32'hxxxxxxxx;   assign  wn_im[211] = 32'hxxxxxxxx;   // 211  0.450  0.893
assign  wn_re[212] = 32'hxxxxxxxx;   assign  wn_im[212] = 32'hxxxxxxxx;   // 212  0.471  0.882
assign  wn_re[213] = 32'hxxxxxxxx;   assign  wn_im[213] = 32'hxxxxxxxx;   // 213  0.493  0.870
assign  wn_re[214] = 32'hxxxxxxxx;   assign  wn_im[214] = 32'hxxxxxxxx;   // 214  0.514  0.858
assign  wn_re[215] = 32'hxxxxxxxx;   assign  wn_im[215] = 32'hxxxxxxxx;   // 215  0.535  0.845
assign  wn_re[216] = 32'hxxxxxxxx;   assign  wn_im[216] = 32'hxxxxxxxx;   // 216  0.556  0.831
assign  wn_re[217] = 32'hxxxxxxxx;   assign  wn_im[217] = 32'hxxxxxxxx;   // 217  0.576  0.818
assign  wn_re[218] = 32'hxxxxxxxx;   assign  wn_im[218] = 32'hxxxxxxxx;   // 218  0.596  0.803
assign  wn_re[219] = 32'hxxxxxxxx;   assign  wn_im[219] = 32'hxxxxxxxx;   // 219  0.615  0.788
assign  wn_re[220] = 32'hxxxxxxxx;   assign  wn_im[220] = 32'hxxxxxxxx;   // 220  0.634  0.773
assign  wn_re[221] = 32'hxxxxxxxx;   assign  wn_im[221] = 32'hxxxxxxxx;   // 221  0.653  0.757
assign  wn_re[222] = 32'hxxxxxxxx;   assign  wn_im[222] = 32'hxxxxxxxx;   // 222  0.672  0.741
assign  wn_re[223] = 32'hxxxxxxxx;   assign  wn_im[223] = 32'hxxxxxxxx;   // 223  0.690  0.724
assign  wn_re[224] = 32'hxxxxxxxx;   assign  wn_im[224] = 32'hxxxxxxxx;   // 224  0.707  0.707
assign  wn_re[225] = 32'hxxxxxxxx;   assign  wn_im[225] = 32'hxxxxxxxx;   // 225  0.724  0.690
assign  wn_re[226] = 32'hxxxxxxxx;   assign  wn_im[226] = 32'hxxxxxxxx;   // 226  0.741  0.672
assign  wn_re[227] = 32'hxxxxxxxx;   assign  wn_im[227] = 32'hxxxxxxxx;   // 227  0.757  0.653
assign  wn_re[228] = 32'hxxxxxxxx;   assign  wn_im[228] = 32'hxxxxxxxx;   // 228  0.773  0.634
assign  wn_re[229] = 32'hxxxxxxxx;   assign  wn_im[229] = 32'hxxxxxxxx;   // 229  0.788  0.615
assign  wn_re[230] = 32'hxxxxxxxx;   assign  wn_im[230] = 32'hxxxxxxxx;   // 230  0.803  0.596
assign  wn_re[231] = 32'hxxxxxxxx;   assign  wn_im[231] = 32'hxxxxxxxx;   // 231  0.818  0.576
assign  wn_re[232] = 32'hxxxxxxxx;   assign  wn_im[232] = 32'hxxxxxxxx;   // 232  0.831  0.556
assign  wn_re[233] = 32'hxxxxxxxx;   assign  wn_im[233] = 32'hxxxxxxxx;   // 233  0.845  0.535
assign  wn_re[234] = 32'hxxxxxxxx;   assign  wn_im[234] = 32'hxxxxxxxx;   // 234  0.858  0.514
assign  wn_re[235] = 32'hxxxxxxxx;   assign  wn_im[235] = 32'hxxxxxxxx;   // 235  0.870  0.493
assign  wn_re[236] = 32'hxxxxxxxx;   assign  wn_im[236] = 32'hxxxxxxxx;   // 236  0.882  0.471
assign  wn_re[237] = 32'hxxxxxxxx;   assign  wn_im[237] = 32'hxxxxxxxx;   // 237  0.893  0.450
assign  wn_re[238] = 32'hxxxxxxxx;   assign  wn_im[238] = 32'hxxxxxxxx;   // 238  0.904  0.428
assign  wn_re[239] = 32'hxxxxxxxx;   assign  wn_im[239] = 32'hxxxxxxxx;   // 239  0.914  0.405
assign  wn_re[240] = 32'hxxxxxxxx;   assign  wn_im[240] = 32'hxxxxxxxx;   // 240  0.924  0.383
assign  wn_re[241] = 32'hxxxxxxxx;   assign  wn_im[241] = 32'hxxxxxxxx;   // 241  0.933  0.360
assign  wn_re[242] = 32'hxxxxxxxx;   assign  wn_im[242] = 32'hxxxxxxxx;   // 242  0.942  0.337
assign  wn_re[243] = 32'hxxxxxxxx;   assign  wn_im[243] = 32'hxxxxxxxx;   // 243  0.950  0.314
assign  wn_re[244] = 32'hxxxxxxxx;   assign  wn_im[244] = 32'hxxxxxxxx;   // 244  0.957  0.290
assign  wn_re[245] = 32'hxxxxxxxx;   assign  wn_im[245] = 32'hxxxxxxxx;   // 245  0.964  0.267
assign  wn_re[246] = 32'hxxxxxxxx;   assign  wn_im[246] = 32'hxxxxxxxx;   // 246  0.970  0.243
assign  wn_re[247] = 32'hxxxxxxxx;   assign  wn_im[247] = 32'hxxxxxxxx;   // 247  0.976  0.219
assign  wn_re[248] = 32'hxxxxxxxx;   assign  wn_im[248] = 32'hxxxxxxxx;   // 248  0.981  0.195
assign  wn_re[249] = 32'hxxxxxxxx;   assign  wn_im[249] = 32'hxxxxxxxx;   // 249  0.985  0.171
assign  wn_re[250] = 32'hxxxxxxxx;   assign  wn_im[250] = 32'hxxxxxxxx;   // 250  0.989  0.147
assign  wn_re[251] = 32'hxxxxxxxx;   assign  wn_im[251] = 32'hxxxxxxxx;   // 251  0.992  0.122
assign  wn_re[252] = 32'hxxxxxxxx;   assign  wn_im[252] = 32'hxxxxxxxx;   // 252  0.995  0.098
assign  wn_re[253] = 32'hxxxxxxxx;   assign  wn_im[253] = 32'hxxxxxxxx;   // 253  0.997  0.074
assign  wn_re[254] = 32'hxxxxxxxx;   assign  wn_im[254] = 32'hxxxxxxxx;   // 254  0.999  0.049
assign  wn_re[255] = 32'hxxxxxxxx;   assign  wn_im[255] = 32'hxxxxxxxx;   // 255  1.000  0.025

endmodule
