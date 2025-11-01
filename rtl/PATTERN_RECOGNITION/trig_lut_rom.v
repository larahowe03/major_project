// ============================================================
// Auto-generated Q1.15 trig LUT ROM (180 entries)
// ============================================================
module trig_lut_rom (
    input  logic clk,
    input  logic [$clog2(180)-1:0] theta_idx,
    output logic signed [15:0] cos_q,
    output logic signed [15:0] sin_q
);

    // Synchronous ROMs (Q1.15 fixed-point)
    reg signed [15:0] cos_rom [0:179];
    reg signed [15:0] sin_rom [0:179];

    initial begin
        cos_rom[0] = 16'sh7FFF;  // cos(  0�) = 0.999969
        cos_rom[1] = 16'sh7FFA;  // cos(  1�) = 0.999817
        cos_rom[2] = 16'sh7FEB;  // cos(  2�) = 0.999359
        cos_rom[3] = 16'sh7FD2;  // cos(  3�) = 0.998596
        cos_rom[4] = 16'sh7FAF;  // cos(  4�) = 0.997528
        cos_rom[5] = 16'sh7F82;  // cos(  5�) = 0.996155
        cos_rom[6] = 16'sh7F4B;  // cos(  6�) = 0.994476
        cos_rom[7] = 16'sh7F0B;  // cos(  7�) = 0.992523
        cos_rom[8] = 16'sh7EC0;  // cos(  8�) = 0.990234
        cos_rom[9] = 16'sh7E6C;  // cos(  9�) = 0.987671
        cos_rom[10] = 16'sh7E0D;  // cos( 10�) = 0.984772
        cos_rom[11] = 16'sh7DA5;  // cos( 11�) = 0.981598
        cos_rom[12] = 16'sh7D33;  // cos( 12�) = 0.978119
        cos_rom[13] = 16'sh7CB7;  // cos( 13�) = 0.974335
        cos_rom[14] = 16'sh7C32;  // cos( 14�) = 0.970276
        cos_rom[15] = 16'sh7BA2;  // cos( 15�) = 0.965881
        cos_rom[16] = 16'sh7B0A;  // cos( 16�) = 0.961243
        cos_rom[17] = 16'sh7A67;  // cos( 17�) = 0.956268
        cos_rom[18] = 16'sh79BB;  // cos( 18�) = 0.951019
        cos_rom[19] = 16'sh7906;  // cos( 19�) = 0.945496
        cos_rom[20] = 16'sh7847;  // cos( 20�) = 0.939667
        cos_rom[21] = 16'sh777F;  // cos( 21�) = 0.933563
        cos_rom[22] = 16'sh76AD;  // cos( 22�) = 0.927155
        cos_rom[23] = 16'sh75D2;  // cos( 23�) = 0.920471
        cos_rom[24] = 16'sh74EE;  // cos( 24�) = 0.913513
        cos_rom[25] = 16'sh7401;  // cos( 25�) = 0.906281
        cos_rom[26] = 16'sh730B;  // cos( 26�) = 0.898773
        cos_rom[27] = 16'sh720C;  // cos( 27�) = 0.890991
        cos_rom[28] = 16'sh7104;  // cos( 28�) = 0.882935
        cos_rom[29] = 16'sh6FF3;  // cos( 29�) = 0.874603
        cos_rom[30] = 16'sh6ED9;  // cos( 30�) = 0.865997
        cos_rom[31] = 16'sh6DB7;  // cos( 31�) = 0.857147
        cos_rom[32] = 16'sh6C8C;  // cos( 32�) = 0.848022
        cos_rom[33] = 16'sh6B59;  // cos( 33�) = 0.838654
        cos_rom[34] = 16'sh6A1D;  // cos( 34�) = 0.829010
        cos_rom[35] = 16'sh68D9;  // cos( 35�) = 0.819122
        cos_rom[36] = 16'sh678D;  // cos( 36�) = 0.808990
        cos_rom[37] = 16'sh6639;  // cos( 37�) = 0.798615
        cos_rom[38] = 16'sh64DD;  // cos( 38�) = 0.787994
        cos_rom[39] = 16'sh6379;  // cos( 39�) = 0.777130
        cos_rom[40] = 16'sh620D;  // cos( 40�) = 0.766022
        cos_rom[41] = 16'sh609A;  // cos( 41�) = 0.754700
        cos_rom[42] = 16'sh5F1F;  // cos( 42�) = 0.743134
        cos_rom[43] = 16'sh5D9C;  // cos( 43�) = 0.731323
        cos_rom[44] = 16'sh5C13;  // cos( 44�) = 0.719330
        cos_rom[45] = 16'sh5A82;  // cos( 45�) = 0.707092
        cos_rom[46] = 16'sh58EA;  // cos( 46�) = 0.694641
        cos_rom[47] = 16'sh574B;  // cos( 47�) = 0.681976
        cos_rom[48] = 16'sh55A5;  // cos( 48�) = 0.669098
        cos_rom[49] = 16'sh53F9;  // cos( 49�) = 0.656036
        cos_rom[50] = 16'sh5246;  // cos( 50�) = 0.642761
        cos_rom[51] = 16'sh508D;  // cos( 51�) = 0.629303
        cos_rom[52] = 16'sh4ECD;  // cos( 52�) = 0.615631
        cos_rom[53] = 16'sh4D08;  // cos( 53�) = 0.601807
        cos_rom[54] = 16'sh4B3C;  // cos( 54�) = 0.587769
        cos_rom[55] = 16'sh496A;  // cos( 55�) = 0.573547
        cos_rom[56] = 16'sh4793;  // cos( 56�) = 0.559174
        cos_rom[57] = 16'sh45B6;  // cos( 57�) = 0.544617
        cos_rom[58] = 16'sh43D4;  // cos( 58�) = 0.529907
        cos_rom[59] = 16'sh41EC;  // cos( 59�) = 0.515015
        cos_rom[60] = 16'sh4000;  // cos( 60�) = 0.500000
        cos_rom[61] = 16'sh3E0E;  // cos( 61�) = 0.484802
        cos_rom[62] = 16'sh3C17;  // cos( 62�) = 0.469452
        cos_rom[63] = 16'sh3A1C;  // cos( 63�) = 0.453979
        cos_rom[64] = 16'sh381C;  // cos( 64�) = 0.438354
        cos_rom[65] = 16'sh3618;  // cos( 65�) = 0.422607
        cos_rom[66] = 16'sh3410;  // cos( 66�) = 0.406738
        cos_rom[67] = 16'sh3203;  // cos( 67�) = 0.390717
        cos_rom[68] = 16'sh2FF3;  // cos( 68�) = 0.374603
        cos_rom[69] = 16'sh2DDF;  // cos( 69�) = 0.358368
        cos_rom[70] = 16'sh2BC7;  // cos( 70�) = 0.342010
        cos_rom[71] = 16'sh29AC;  // cos( 71�) = 0.325562
        cos_rom[72] = 16'sh278E;  // cos( 72�) = 0.309021
        cos_rom[73] = 16'sh256C;  // cos( 73�) = 0.292358
        cos_rom[74] = 16'sh2348;  // cos( 74�) = 0.275635
        cos_rom[75] = 16'sh2121;  // cos( 75�) = 0.258820
        cos_rom[76] = 16'sh1EF7;  // cos( 76�) = 0.241913
        cos_rom[77] = 16'sh1CCB;  // cos( 77�) = 0.224945
        cos_rom[78] = 16'sh1A9D;  // cos( 78�) = 0.207916
        cos_rom[79] = 16'sh186C;  // cos( 79�) = 0.190796
        cos_rom[80] = 16'sh163A;  // cos( 80�) = 0.173645
        cos_rom[81] = 16'sh1406;  // cos( 81�) = 0.156433
        cos_rom[82] = 16'sh11D0;  // cos( 82�) = 0.139160
        cos_rom[83] = 16'sh0F99;  // cos( 83�) = 0.121857
        cos_rom[84] = 16'sh0D61;  // cos( 84�) = 0.104523
        cos_rom[85] = 16'sh0B28;  // cos( 85�) = 0.087158
        cos_rom[86] = 16'sh08EE;  // cos( 86�) = 0.069763
        cos_rom[87] = 16'sh06B3;  // cos( 87�) = 0.052338
        cos_rom[88] = 16'sh0478;  // cos( 88�) = 0.034912
        cos_rom[89] = 16'sh023C;  // cos( 89�) = 0.017456
        cos_rom[90] = 16'sh0000;  // cos( 90�) = 0.000000
        cos_rom[91] = 16'shFDC4;  // cos( 91�) = -0.017456
        cos_rom[92] = 16'shFB88;  // cos( 92�) = -0.034912
        cos_rom[93] = 16'shF94D;  // cos( 93�) = -0.052338
        cos_rom[94] = 16'shF712;  // cos( 94�) = -0.069763
        cos_rom[95] = 16'shF4D8;  // cos( 95�) = -0.087158
        cos_rom[96] = 16'shF29F;  // cos( 96�) = -0.104523
        cos_rom[97] = 16'shF067;  // cos( 97�) = -0.121857
        cos_rom[98] = 16'shEE30;  // cos( 98�) = -0.139160
        cos_rom[99] = 16'shEBFA;  // cos( 99�) = -0.156433
        cos_rom[100] = 16'shE9C6;  // cos(100�) = -0.173645
        cos_rom[101] = 16'shE794;  // cos(101�) = -0.190796
        cos_rom[102] = 16'shE563;  // cos(102�) = -0.207916
        cos_rom[103] = 16'shE335;  // cos(103�) = -0.224945
        cos_rom[104] = 16'shE109;  // cos(104�) = -0.241913
        cos_rom[105] = 16'shDEDF;  // cos(105�) = -0.258820
        cos_rom[106] = 16'shDCB8;  // cos(106�) = -0.275635
        cos_rom[107] = 16'shDA94;  // cos(107�) = -0.292358
        cos_rom[108] = 16'shD872;  // cos(108�) = -0.309021
        cos_rom[109] = 16'shD654;  // cos(109�) = -0.325562
        cos_rom[110] = 16'shD439;  // cos(110�) = -0.342010
        cos_rom[111] = 16'shD221;  // cos(111�) = -0.358368
        cos_rom[112] = 16'shD00D;  // cos(112�) = -0.374603
        cos_rom[113] = 16'shCDFD;  // cos(113�) = -0.390717
        cos_rom[114] = 16'shCBF0;  // cos(114�) = -0.406738
        cos_rom[115] = 16'shC9E8;  // cos(115�) = -0.422607
        cos_rom[116] = 16'shC7E4;  // cos(116�) = -0.438354
        cos_rom[117] = 16'shC5E4;  // cos(117�) = -0.453979
        cos_rom[118] = 16'shC3E9;  // cos(118�) = -0.469452
        cos_rom[119] = 16'shC1F2;  // cos(119�) = -0.484802
        cos_rom[120] = 16'shC001;  // cos(120�) = -0.499969
        cos_rom[121] = 16'shBE14;  // cos(121�) = -0.515015
        cos_rom[122] = 16'shBC2C;  // cos(122�) = -0.529907
        cos_rom[123] = 16'shBA4A;  // cos(123�) = -0.544617
        cos_rom[124] = 16'shB86D;  // cos(124�) = -0.559174
        cos_rom[125] = 16'shB696;  // cos(125�) = -0.573547
        cos_rom[126] = 16'shB4C4;  // cos(126�) = -0.587769
        cos_rom[127] = 16'shB2F8;  // cos(127�) = -0.601807
        cos_rom[128] = 16'shB133;  // cos(128�) = -0.615631
        cos_rom[129] = 16'shAF73;  // cos(129�) = -0.629303
        cos_rom[130] = 16'shADBA;  // cos(130�) = -0.642761
        cos_rom[131] = 16'shAC07;  // cos(131�) = -0.656036
        cos_rom[132] = 16'shAA5B;  // cos(132�) = -0.669098
        cos_rom[133] = 16'shA8B5;  // cos(133�) = -0.681976
        cos_rom[134] = 16'shA716;  // cos(134�) = -0.694641
        cos_rom[135] = 16'shA57E;  // cos(135�) = -0.707092
        cos_rom[136] = 16'shA3ED;  // cos(136�) = -0.719330
        cos_rom[137] = 16'shA264;  // cos(137�) = -0.731323
        cos_rom[138] = 16'shA0E1;  // cos(138�) = -0.743134
        cos_rom[139] = 16'sh9F66;  // cos(139�) = -0.754700
        cos_rom[140] = 16'sh9DF3;  // cos(140�) = -0.766022
        cos_rom[141] = 16'sh9C87;  // cos(141�) = -0.777130
        cos_rom[142] = 16'sh9B23;  // cos(142�) = -0.787994
        cos_rom[143] = 16'sh99C7;  // cos(143�) = -0.798615
        cos_rom[144] = 16'sh9873;  // cos(144�) = -0.808990
        cos_rom[145] = 16'sh9727;  // cos(145�) = -0.819122
        cos_rom[146] = 16'sh95E3;  // cos(146�) = -0.829010
        cos_rom[147] = 16'sh94A7;  // cos(147�) = -0.838654
        cos_rom[148] = 16'sh9374;  // cos(148�) = -0.848022
        cos_rom[149] = 16'sh9249;  // cos(149�) = -0.857147
        cos_rom[150] = 16'sh9127;  // cos(150�) = -0.865997
        cos_rom[151] = 16'sh900D;  // cos(151�) = -0.874603
        cos_rom[152] = 16'sh8EFC;  // cos(152�) = -0.882935
        cos_rom[153] = 16'sh8DF4;  // cos(153�) = -0.890991
        cos_rom[154] = 16'sh8CF5;  // cos(154�) = -0.898773
        cos_rom[155] = 16'sh8BFF;  // cos(155�) = -0.906281
        cos_rom[156] = 16'sh8B12;  // cos(156�) = -0.913513
        cos_rom[157] = 16'sh8A2E;  // cos(157�) = -0.920471
        cos_rom[158] = 16'sh8953;  // cos(158�) = -0.927155
        cos_rom[159] = 16'sh8881;  // cos(159�) = -0.933563
        cos_rom[160] = 16'sh87B9;  // cos(160�) = -0.939667
        cos_rom[161] = 16'sh86FA;  // cos(161�) = -0.945496
        cos_rom[162] = 16'sh8645;  // cos(162�) = -0.951019
        cos_rom[163] = 16'sh8599;  // cos(163�) = -0.956268
        cos_rom[164] = 16'sh84F6;  // cos(164�) = -0.961243
        cos_rom[165] = 16'sh845E;  // cos(165�) = -0.965881
        cos_rom[166] = 16'sh83CE;  // cos(166�) = -0.970276
        cos_rom[167] = 16'sh8349;  // cos(167�) = -0.974335
        cos_rom[168] = 16'sh82CD;  // cos(168�) = -0.978119
        cos_rom[169] = 16'sh825B;  // cos(169�) = -0.981598
        cos_rom[170] = 16'sh81F3;  // cos(170�) = -0.984772
        cos_rom[171] = 16'sh8194;  // cos(171�) = -0.987671
        cos_rom[172] = 16'sh8140;  // cos(172�) = -0.990234
        cos_rom[173] = 16'sh80F5;  // cos(173�) = -0.992523
        cos_rom[174] = 16'sh80B5;  // cos(174�) = -0.994476
        cos_rom[175] = 16'sh807E;  // cos(175�) = -0.996155
        cos_rom[176] = 16'sh8051;  // cos(176�) = -0.997528
        cos_rom[177] = 16'sh802E;  // cos(177�) = -0.998596
        cos_rom[178] = 16'sh8015;  // cos(178�) = -0.999359
        cos_rom[179] = 16'sh8006;  // cos(179�) = -0.999817

        sin_rom[0] = 16'sh0000;  // sin(  0�) = 0.000000
        sin_rom[1] = 16'sh023C;  // sin(  1�) = 0.017456
        sin_rom[2] = 16'sh0478;  // sin(  2�) = 0.034912
        sin_rom[3] = 16'sh06B3;  // sin(  3�) = 0.052338
        sin_rom[4] = 16'sh08EE;  // sin(  4�) = 0.069763
        sin_rom[5] = 16'sh0B28;  // sin(  5�) = 0.087158
        sin_rom[6] = 16'sh0D61;  // sin(  6�) = 0.104523
        sin_rom[7] = 16'sh0F99;  // sin(  7�) = 0.121857
        sin_rom[8] = 16'sh11D0;  // sin(  8�) = 0.139160
        sin_rom[9] = 16'sh1406;  // sin(  9�) = 0.156433
        sin_rom[10] = 16'sh163A;  // sin( 10�) = 0.173645
        sin_rom[11] = 16'sh186C;  // sin( 11�) = 0.190796
        sin_rom[12] = 16'sh1A9D;  // sin( 12�) = 0.207916
        sin_rom[13] = 16'sh1CCB;  // sin( 13�) = 0.224945
        sin_rom[14] = 16'sh1EF7;  // sin( 14�) = 0.241913
        sin_rom[15] = 16'sh2121;  // sin( 15�) = 0.258820
        sin_rom[16] = 16'sh2348;  // sin( 16�) = 0.275635
        sin_rom[17] = 16'sh256C;  // sin( 17�) = 0.292358
        sin_rom[18] = 16'sh278E;  // sin( 18�) = 0.309021
        sin_rom[19] = 16'sh29AC;  // sin( 19�) = 0.325562
        sin_rom[20] = 16'sh2BC7;  // sin( 20�) = 0.342010
        sin_rom[21] = 16'sh2DDF;  // sin( 21�) = 0.358368
        sin_rom[22] = 16'sh2FF3;  // sin( 22�) = 0.374603
        sin_rom[23] = 16'sh3203;  // sin( 23�) = 0.390717
        sin_rom[24] = 16'sh3410;  // sin( 24�) = 0.406738
        sin_rom[25] = 16'sh3618;  // sin( 25�) = 0.422607
        sin_rom[26] = 16'sh381C;  // sin( 26�) = 0.438354
        sin_rom[27] = 16'sh3A1C;  // sin( 27�) = 0.453979
        sin_rom[28] = 16'sh3C17;  // sin( 28�) = 0.469452
        sin_rom[29] = 16'sh3E0E;  // sin( 29�) = 0.484802
        sin_rom[30] = 16'sh3FFF;  // sin( 30�) = 0.499969
        sin_rom[31] = 16'sh41EC;  // sin( 31�) = 0.515015
        sin_rom[32] = 16'sh43D4;  // sin( 32�) = 0.529907
        sin_rom[33] = 16'sh45B6;  // sin( 33�) = 0.544617
        sin_rom[34] = 16'sh4793;  // sin( 34�) = 0.559174
        sin_rom[35] = 16'sh496A;  // sin( 35�) = 0.573547
        sin_rom[36] = 16'sh4B3C;  // sin( 36�) = 0.587769
        sin_rom[37] = 16'sh4D08;  // sin( 37�) = 0.601807
        sin_rom[38] = 16'sh4ECD;  // sin( 38�) = 0.615631
        sin_rom[39] = 16'sh508D;  // sin( 39�) = 0.629303
        sin_rom[40] = 16'sh5246;  // sin( 40�) = 0.642761
        sin_rom[41] = 16'sh53F9;  // sin( 41�) = 0.656036
        sin_rom[42] = 16'sh55A5;  // sin( 42�) = 0.669098
        sin_rom[43] = 16'sh574B;  // sin( 43�) = 0.681976
        sin_rom[44] = 16'sh58EA;  // sin( 44�) = 0.694641
        sin_rom[45] = 16'sh5A82;  // sin( 45�) = 0.707092
        sin_rom[46] = 16'sh5C13;  // sin( 46�) = 0.719330
        sin_rom[47] = 16'sh5D9C;  // sin( 47�) = 0.731323
        sin_rom[48] = 16'sh5F1F;  // sin( 48�) = 0.743134
        sin_rom[49] = 16'sh609A;  // sin( 49�) = 0.754700
        sin_rom[50] = 16'sh620D;  // sin( 50�) = 0.766022
        sin_rom[51] = 16'sh6379;  // sin( 51�) = 0.777130
        sin_rom[52] = 16'sh64DD;  // sin( 52�) = 0.787994
        sin_rom[53] = 16'sh6639;  // sin( 53�) = 0.798615
        sin_rom[54] = 16'sh678D;  // sin( 54�) = 0.808990
        sin_rom[55] = 16'sh68D9;  // sin( 55�) = 0.819122
        sin_rom[56] = 16'sh6A1D;  // sin( 56�) = 0.829010
        sin_rom[57] = 16'sh6B59;  // sin( 57�) = 0.838654
        sin_rom[58] = 16'sh6C8C;  // sin( 58�) = 0.848022
        sin_rom[59] = 16'sh6DB7;  // sin( 59�) = 0.857147
        sin_rom[60] = 16'sh6ED9;  // sin( 60�) = 0.865997
        sin_rom[61] = 16'sh6FF3;  // sin( 61�) = 0.874603
        sin_rom[62] = 16'sh7104;  // sin( 62�) = 0.882935
        sin_rom[63] = 16'sh720C;  // sin( 63�) = 0.890991
        sin_rom[64] = 16'sh730B;  // sin( 64�) = 0.898773
        sin_rom[65] = 16'sh7401;  // sin( 65�) = 0.906281
        sin_rom[66] = 16'sh74EE;  // sin( 66�) = 0.913513
        sin_rom[67] = 16'sh75D2;  // sin( 67�) = 0.920471
        sin_rom[68] = 16'sh76AD;  // sin( 68�) = 0.927155
        sin_rom[69] = 16'sh777F;  // sin( 69�) = 0.933563
        sin_rom[70] = 16'sh7847;  // sin( 70�) = 0.939667
        sin_rom[71] = 16'sh7906;  // sin( 71�) = 0.945496
        sin_rom[72] = 16'sh79BB;  // sin( 72�) = 0.951019
        sin_rom[73] = 16'sh7A67;  // sin( 73�) = 0.956268
        sin_rom[74] = 16'sh7B0A;  // sin( 74�) = 0.961243
        sin_rom[75] = 16'sh7BA2;  // sin( 75�) = 0.965881
        sin_rom[76] = 16'sh7C32;  // sin( 76�) = 0.970276
        sin_rom[77] = 16'sh7CB7;  // sin( 77�) = 0.974335
        sin_rom[78] = 16'sh7D33;  // sin( 78�) = 0.978119
        sin_rom[79] = 16'sh7DA5;  // sin( 79�) = 0.981598
        sin_rom[80] = 16'sh7E0D;  // sin( 80�) = 0.984772
        sin_rom[81] = 16'sh7E6C;  // sin( 81�) = 0.987671
        sin_rom[82] = 16'sh7EC0;  // sin( 82�) = 0.990234
        sin_rom[83] = 16'sh7F0B;  // sin( 83�) = 0.992523
        sin_rom[84] = 16'sh7F4B;  // sin( 84�) = 0.994476
        sin_rom[85] = 16'sh7F82;  // sin( 85�) = 0.996155
        sin_rom[86] = 16'sh7FAF;  // sin( 86�) = 0.997528
        sin_rom[87] = 16'sh7FD2;  // sin( 87�) = 0.998596
        sin_rom[88] = 16'sh7FEB;  // sin( 88�) = 0.999359
        sin_rom[89] = 16'sh7FFA;  // sin( 89�) = 0.999817
        sin_rom[90] = 16'sh7FFF;  // sin( 90�) = 0.999969
        sin_rom[91] = 16'sh7FFA;  // sin( 91�) = 0.999817
        sin_rom[92] = 16'sh7FEB;  // sin( 92�) = 0.999359
        sin_rom[93] = 16'sh7FD2;  // sin( 93�) = 0.998596
        sin_rom[94] = 16'sh7FAF;  // sin( 94�) = 0.997528
        sin_rom[95] = 16'sh7F82;  // sin( 95�) = 0.996155
        sin_rom[96] = 16'sh7F4B;  // sin( 96�) = 0.994476
        sin_rom[97] = 16'sh7F0B;  // sin( 97�) = 0.992523
        sin_rom[98] = 16'sh7EC0;  // sin( 98�) = 0.990234
        sin_rom[99] = 16'sh7E6C;  // sin( 99�) = 0.987671
        sin_rom[100] = 16'sh7E0D;  // sin(100�) = 0.984772
        sin_rom[101] = 16'sh7DA5;  // sin(101�) = 0.981598
        sin_rom[102] = 16'sh7D33;  // sin(102�) = 0.978119
        sin_rom[103] = 16'sh7CB7;  // sin(103�) = 0.974335
        sin_rom[104] = 16'sh7C32;  // sin(104�) = 0.970276
        sin_rom[105] = 16'sh7BA2;  // sin(105�) = 0.965881
        sin_rom[106] = 16'sh7B0A;  // sin(106�) = 0.961243
        sin_rom[107] = 16'sh7A67;  // sin(107�) = 0.956268
        sin_rom[108] = 16'sh79BB;  // sin(108�) = 0.951019
        sin_rom[109] = 16'sh7906;  // sin(109�) = 0.945496
        sin_rom[110] = 16'sh7847;  // sin(110�) = 0.939667
        sin_rom[111] = 16'sh777F;  // sin(111�) = 0.933563
        sin_rom[112] = 16'sh76AD;  // sin(112�) = 0.927155
        sin_rom[113] = 16'sh75D2;  // sin(113�) = 0.920471
        sin_rom[114] = 16'sh74EE;  // sin(114�) = 0.913513
        sin_rom[115] = 16'sh7401;  // sin(115�) = 0.906281
        sin_rom[116] = 16'sh730B;  // sin(116�) = 0.898773
        sin_rom[117] = 16'sh720C;  // sin(117�) = 0.890991
        sin_rom[118] = 16'sh7104;  // sin(118�) = 0.882935
        sin_rom[119] = 16'sh6FF3;  // sin(119�) = 0.874603
        sin_rom[120] = 16'sh6ED9;  // sin(120�) = 0.865997
        sin_rom[121] = 16'sh6DB7;  // sin(121�) = 0.857147
        sin_rom[122] = 16'sh6C8C;  // sin(122�) = 0.848022
        sin_rom[123] = 16'sh6B59;  // sin(123�) = 0.838654
        sin_rom[124] = 16'sh6A1D;  // sin(124�) = 0.829010
        sin_rom[125] = 16'sh68D9;  // sin(125�) = 0.819122
        sin_rom[126] = 16'sh678D;  // sin(126�) = 0.808990
        sin_rom[127] = 16'sh6639;  // sin(127�) = 0.798615
        sin_rom[128] = 16'sh64DD;  // sin(128�) = 0.787994
        sin_rom[129] = 16'sh6379;  // sin(129�) = 0.777130
        sin_rom[130] = 16'sh620D;  // sin(130�) = 0.766022
        sin_rom[131] = 16'sh609A;  // sin(131�) = 0.754700
        sin_rom[132] = 16'sh5F1F;  // sin(132�) = 0.743134
        sin_rom[133] = 16'sh5D9C;  // sin(133�) = 0.731323
        sin_rom[134] = 16'sh5C13;  // sin(134�) = 0.719330
        sin_rom[135] = 16'sh5A82;  // sin(135�) = 0.707092
        sin_rom[136] = 16'sh58EA;  // sin(136�) = 0.694641
        sin_rom[137] = 16'sh574B;  // sin(137�) = 0.681976
        sin_rom[138] = 16'sh55A5;  // sin(138�) = 0.669098
        sin_rom[139] = 16'sh53F9;  // sin(139�) = 0.656036
        sin_rom[140] = 16'sh5246;  // sin(140�) = 0.642761
        sin_rom[141] = 16'sh508D;  // sin(141�) = 0.629303
        sin_rom[142] = 16'sh4ECD;  // sin(142�) = 0.615631
        sin_rom[143] = 16'sh4D08;  // sin(143�) = 0.601807
        sin_rom[144] = 16'sh4B3C;  // sin(144�) = 0.587769
        sin_rom[145] = 16'sh496A;  // sin(145�) = 0.573547
        sin_rom[146] = 16'sh4793;  // sin(146�) = 0.559174
        sin_rom[147] = 16'sh45B6;  // sin(147�) = 0.544617
        sin_rom[148] = 16'sh43D4;  // sin(148�) = 0.529907
        sin_rom[149] = 16'sh41EC;  // sin(149�) = 0.515015
        sin_rom[150] = 16'sh3FFF;  // sin(150�) = 0.499969
        sin_rom[151] = 16'sh3E0E;  // sin(151�) = 0.484802
        sin_rom[152] = 16'sh3C17;  // sin(152�) = 0.469452
        sin_rom[153] = 16'sh3A1C;  // sin(153�) = 0.453979
        sin_rom[154] = 16'sh381C;  // sin(154�) = 0.438354
        sin_rom[155] = 16'sh3618;  // sin(155�) = 0.422607
        sin_rom[156] = 16'sh3410;  // sin(156�) = 0.406738
        sin_rom[157] = 16'sh3203;  // sin(157�) = 0.390717
        sin_rom[158] = 16'sh2FF3;  // sin(158�) = 0.374603
        sin_rom[159] = 16'sh2DDF;  // sin(159�) = 0.358368
        sin_rom[160] = 16'sh2BC7;  // sin(160�) = 0.342010
        sin_rom[161] = 16'sh29AC;  // sin(161�) = 0.325562
        sin_rom[162] = 16'sh278E;  // sin(162�) = 0.309021
        sin_rom[163] = 16'sh256C;  // sin(163�) = 0.292358
        sin_rom[164] = 16'sh2348;  // sin(164�) = 0.275635
        sin_rom[165] = 16'sh2121;  // sin(165�) = 0.258820
        sin_rom[166] = 16'sh1EF7;  // sin(166�) = 0.241913
        sin_rom[167] = 16'sh1CCB;  // sin(167�) = 0.224945
        sin_rom[168] = 16'sh1A9D;  // sin(168�) = 0.207916
        sin_rom[169] = 16'sh186C;  // sin(169�) = 0.190796
        sin_rom[170] = 16'sh163A;  // sin(170�) = 0.173645
        sin_rom[171] = 16'sh1406;  // sin(171�) = 0.156433
        sin_rom[172] = 16'sh11D0;  // sin(172�) = 0.139160
        sin_rom[173] = 16'sh0F99;  // sin(173�) = 0.121857
        sin_rom[174] = 16'sh0D61;  // sin(174�) = 0.104523
        sin_rom[175] = 16'sh0B28;  // sin(175�) = 0.087158
        sin_rom[176] = 16'sh08EE;  // sin(176�) = 0.069763
        sin_rom[177] = 16'sh06B3;  // sin(177�) = 0.052338
        sin_rom[178] = 16'sh0478;  // sin(178�) = 0.034912
        sin_rom[179] = 16'sh023C;  // sin(179�) = 0.017456
    end

    always_ff @(posedge clk) begin
        cos_q <= cos_rom[theta_idx];
        sin_q <= sin_rom[theta_idx];
    end

endmodule
// ============================================================
