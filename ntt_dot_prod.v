`timescale 1ns / 1ps
module ntt_dot_prod #(
    parameter Q = 3329,
    parameter IS_RRLWE = 1,
    parameter IS_BRMLWE = 0
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    output reg  [7:0]  addr_a0,
    output reg  [7:0]  addr_a1,
    input  wire [11:0] dout_a0,
    input  wire [11:0] dout_a1,
    output reg  [7:0]  addr_b0,
    output reg  [7:0]  addr_b1,
    input  wire [11:0] dout_b0,
    input  wire [11:0] dout_b1,
    output reg         out_valid,
    output reg  [7:0]  out_addr0,
    output reg  [7:0]  out_addr1,
    output reg  [11:0] out_c0,
    output reg  [11:0] out_c1,
    input wire         twist_enable
);
    (* rom_style = "block" *) reg [11:0] zeta_rom [0:255];
    initial begin
        zeta_rom[0] = 12'd767;
        zeta_rom[1] = 12'd3052;
        zeta_rom[2] = 12'd1949;
        zeta_rom[3] = 12'd3172;
        zeta_rom[4] = 12'd660;
        zeta_rom[5] = 12'd1233;
        zeta_rom[6] = 12'd987;
        zeta_rom[7] = 12'd134;
        zeta_rom[8] = 12'd2278;
        zeta_rom[9] = 12'd2107;
        zeta_rom[10] = 12'd2529;
        zeta_rom[11] = 12'd3045;
        zeta_rom[12] = 12'd1830;
        zeta_rom[13] = 12'd1149;
        zeta_rom[14] = 12'd2888;
        zeta_rom[15] = 12'd2490;
        zeta_rom[16] = 12'd2382;
        zeta_rom[17] = 12'd546;
        zeta_rom[18] = 12'd2624;
        zeta_rom[19] = 12'd1331;
        zeta_rom[20] = 12'd2653;
        zeta_rom[21] = 12'd1824;
        zeta_rom[22] = 12'd1047;
        zeta_rom[23] = 12'd1154;
        zeta_rom[24] = 12'd2973;
        zeta_rom[25] = 12'd606;
        zeta_rom[26] = 12'd315;
        zeta_rom[27] = 12'd2026;
        zeta_rom[28] = 12'd1152;
        zeta_rom[29] = 12'd2939;
        zeta_rom[30] = 12'd28;
        zeta_rom[31] = 12'd476;
        zeta_rom[32] = 12'd1434;
        zeta_rom[33] = 12'd1075;
        zeta_rom[34] = 12'd1630;
        zeta_rom[35] = 12'd1078;
        zeta_rom[36] = 12'd1681;
        zeta_rom[37] = 12'd1945;
        zeta_rom[38] = 12'd3104;
        zeta_rom[39] = 12'd2833;
        zeta_rom[40] = 12'd1555;
        zeta_rom[41] = 12'd3132;
        zeta_rom[42] = 12'd3309;
        zeta_rom[43] = 12'd2989;
        zeta_rom[44] = 12'd878;
        zeta_rom[45] = 12'd1610;
        zeta_rom[46] = 12'd738;
        zeta_rom[47] = 12'd2559;
        zeta_rom[48] = 12'd226;
        zeta_rom[49] = 12'd513;
        zeta_rom[50] = 12'd2063;
        zeta_rom[51] = 12'd1781;
        zeta_rom[52] = 12'd316;
        zeta_rom[53] = 12'd2043;
        zeta_rom[54] = 12'd1441;
        zeta_rom[55] = 12'd1194;
        zeta_rom[56] = 12'd324;
        zeta_rom[57] = 12'd2179;
        zeta_rom[58] = 12'd424;
        zeta_rom[59] = 12'd550;
        zeta_rom[60] = 12'd2692;
        zeta_rom[61] = 12'd2487;
        zeta_rom[62] = 12'd2331;
        zeta_rom[63] = 12'd3008;
        zeta_rom[64] = 12'd1201;
        zeta_rom[65] = 12'd443;
        zeta_rom[66] = 12'd873;
        zeta_rom[67] = 12'd1525;
        zeta_rom[68] = 12'd2622;
        zeta_rom[69] = 12'd1297;
        zeta_rom[70] = 12'd2075;
        zeta_rom[71] = 12'd1985;
        zeta_rom[72] = 12'd455;
        zeta_rom[73] = 12'd1077;
        zeta_rom[74] = 12'd1664;
        zeta_rom[75] = 12'd1656;
        zeta_rom[76] = 12'd1520;
        zeta_rom[77] = 12'd2537;
        zeta_rom[78] = 12'd3181;
        zeta_rom[79] = 12'd813;
        zeta_rom[80] = 12'd505;
        zeta_rom[81] = 12'd1927;
        zeta_rom[82] = 12'd2798;
        zeta_rom[83] = 12'd960;
        zeta_rom[84] = 12'd3004;
        zeta_rom[85] = 12'd1133;
        zeta_rom[86] = 12'd2616;
        zeta_rom[87] = 12'd1195;
        zeta_rom[88] = 12'd341;
        zeta_rom[89] = 12'd2468;
        zeta_rom[90] = 12'd2008;
        zeta_rom[91] = 12'd846;
        zeta_rom[92] = 12'd1066;
        zeta_rom[93] = 12'd1477;
        zeta_rom[94] = 12'd1806;
        zeta_rom[95] = 12'd741;
        zeta_rom[96] = 12'd2610;
        zeta_rom[97] = 12'd1093;
        zeta_rom[98] = 12'd1936;
        zeta_rom[99] = 12'd2951;
        zeta_rom[100] = 12'd232;
        zeta_rom[101] = 12'd615;
        zeta_rom[102] = 12'd468;
        zeta_rom[103] = 12'd1298;
        zeta_rom[104] = 12'd2092;
        zeta_rom[105] = 12'd2274;
        zeta_rom[106] = 12'd2039;
        zeta_rom[107] = 12'd1373;
        zeta_rom[108] = 12'd38;
        zeta_rom[109] = 12'd646;
        zeta_rom[110] = 12'd995;
        zeta_rom[111] = 12'd270;
        zeta_rom[112] = 12'd1261;
        zeta_rom[113] = 12'd1463;
        zeta_rom[114] = 12'd1568;
        zeta_rom[115] = 12'd24;
        zeta_rom[116] = 12'd408;
        zeta_rom[117] = 12'd278;
        zeta_rom[118] = 12'd1397;
        zeta_rom[119] = 12'd446;
        zeta_rom[120] = 12'd924;
        zeta_rom[121] = 12'd2392;
        zeta_rom[122] = 12'd716;
        zeta_rom[123] = 12'd2185;
        zeta_rom[124] = 12'd526;
        zeta_rom[125] = 12'd2284;
        zeta_rom[126] = 12'd2209;
        zeta_rom[127] = 12'd934;
        zeta_rom[128] = 12'd2562;
        zeta_rom[129] = 12'd277;
        zeta_rom[130] = 12'd1380;
        zeta_rom[131] = 12'd157;
        zeta_rom[132] = 12'd2669;
        zeta_rom[133] = 12'd2096;
        zeta_rom[134] = 12'd2342;
        zeta_rom[135] = 12'd3195;
        zeta_rom[136] = 12'd1051;
        zeta_rom[137] = 12'd1222;
        zeta_rom[138] = 12'd800;
        zeta_rom[139] = 12'd284;
        zeta_rom[140] = 12'd1499;
        zeta_rom[141] = 12'd2180;
        zeta_rom[142] = 12'd441;
        zeta_rom[143] = 12'd839;
        zeta_rom[144] = 12'd947;
        zeta_rom[145] = 12'd2783;
        zeta_rom[146] = 12'd705;
        zeta_rom[147] = 12'd1998;
        zeta_rom[148] = 12'd676;
        zeta_rom[149] = 12'd1505;
        zeta_rom[150] = 12'd2282;
        zeta_rom[151] = 12'd2175;
        zeta_rom[152] = 12'd356;
        zeta_rom[153] = 12'd2723;
        zeta_rom[154] = 12'd3014;
        zeta_rom[155] = 12'd1303;
        zeta_rom[156] = 12'd2177;
        zeta_rom[157] = 12'd390;
        zeta_rom[158] = 12'd3301;
        zeta_rom[159] = 12'd2853;
        zeta_rom[160] = 12'd1895;
        zeta_rom[161] = 12'd2254;
        zeta_rom[162] = 12'd1699;
        zeta_rom[163] = 12'd2251;
        zeta_rom[164] = 12'd1648;
        zeta_rom[165] = 12'd1384;
        zeta_rom[166] = 12'd225;
        zeta_rom[167] = 12'd496;
        zeta_rom[168] = 12'd1774;
        zeta_rom[169] = 12'd197;
        zeta_rom[170] = 12'd20;
        zeta_rom[171] = 12'd340;
        zeta_rom[172] = 12'd2451;
        zeta_rom[173] = 12'd1719;
        zeta_rom[174] = 12'd2591;
        zeta_rom[175] = 12'd770;
        zeta_rom[176] = 12'd3103;
        zeta_rom[177] = 12'd2816;
        zeta_rom[178] = 12'd1266;
        zeta_rom[179] = 12'd1548;
        zeta_rom[180] = 12'd3013;
        zeta_rom[181] = 12'd1286;
        zeta_rom[182] = 12'd1888;
        zeta_rom[183] = 12'd2135;
        zeta_rom[184] = 12'd3005;
        zeta_rom[185] = 12'd1150;
        zeta_rom[186] = 12'd2905;
        zeta_rom[187] = 12'd2779;
        zeta_rom[188] = 12'd637;
        zeta_rom[189] = 12'd842;
        zeta_rom[190] = 12'd998;
        zeta_rom[191] = 12'd321;
        zeta_rom[192] = 12'd2128;
        zeta_rom[193] = 12'd2886;
        zeta_rom[194] = 12'd2456;
        zeta_rom[195] = 12'd1804;
        zeta_rom[196] = 12'd707;
        zeta_rom[197] = 12'd2032;
        zeta_rom[198] = 12'd1254;
        zeta_rom[199] = 12'd1344;
        zeta_rom[200] = 12'd2874;
        zeta_rom[201] = 12'd2252;
        zeta_rom[202] = 12'd1665;
        zeta_rom[203] = 12'd1673;
        zeta_rom[204] = 12'd1809;
        zeta_rom[205] = 12'd792;
        zeta_rom[206] = 12'd148;
        zeta_rom[207] = 12'd2516;
        zeta_rom[208] = 12'd2824;
        zeta_rom[209] = 12'd1402;
        zeta_rom[210] = 12'd531;
        zeta_rom[211] = 12'd2369;
        zeta_rom[212] = 12'd325;
        zeta_rom[213] = 12'd2196;
        zeta_rom[214] = 12'd713;
        zeta_rom[215] = 12'd2134;
        zeta_rom[216] = 12'd2988;
        zeta_rom[217] = 12'd861;
        zeta_rom[218] = 12'd1321;
        zeta_rom[219] = 12'd2483;
        zeta_rom[220] = 12'd2263;
        zeta_rom[221] = 12'd1852;
        zeta_rom[222] = 12'd1523;
        zeta_rom[223] = 12'd2588;
        zeta_rom[224] = 12'd719;
        zeta_rom[225] = 12'd2236;
        zeta_rom[226] = 12'd1393;
        zeta_rom[227] = 12'd378;
        zeta_rom[228] = 12'd3097;
        zeta_rom[229] = 12'd2714;
        zeta_rom[230] = 12'd2861;
        zeta_rom[231] = 12'd2031;
        zeta_rom[232] = 12'd1237;
        zeta_rom[233] = 12'd1055;
        zeta_rom[234] = 12'd1290;
        zeta_rom[235] = 12'd1956;
        zeta_rom[236] = 12'd3291;
        zeta_rom[237] = 12'd2683;
        zeta_rom[238] = 12'd2334;
        zeta_rom[239] = 12'd3059;
        zeta_rom[240] = 12'd2068;
        zeta_rom[241] = 12'd1866;
        zeta_rom[242] = 12'd1761;
        zeta_rom[243] = 12'd3305;
        zeta_rom[244] = 12'd2921;
        zeta_rom[245] = 12'd3051;
        zeta_rom[246] = 12'd1932;
        zeta_rom[247] = 12'd2883;
        zeta_rom[248] = 12'd2405;
        zeta_rom[249] = 12'd937;
        zeta_rom[250] = 12'd2613;
        zeta_rom[251] = 12'd1144;
        zeta_rom[252] = 12'd2803;
        zeta_rom[253] = 12'd1045;
        zeta_rom[254] = 12'd1120;
        zeta_rom[255] = 12'd2395;
    end
    localparam IDLE    = 3'b000;
    localparam REQ     = 3'b001; 
    localparam WAIT = 3'b010;
    localparam COMPUTE = 3'b011;  
    localparam FINISH  = 3'b100; 
    reg [2:0] state;
    reg [6:0] i; 
    wire [7:0] idx_even = {i, 1'b0}; 
    wire [7:0] idx_odd  = {i, 1'b1}; 
    wire [11:0] a0     = dout_a0;
    wire [11:0] a1     = dout_a1;
    wire [11:0] b0_raw = dout_b0; 
    wire [11:0] b1_raw = dout_b1;  
    wire [6:0] i_rev = {i[0], i[1], i[2], i[3], i[4], i[5], i[6]};
    wire [7:0] gamma_idx = {i_rev, 1'b1};
    wire [11:0] gamma = zeta_rom[gamma_idx]; 
    wire [12:0] a0_x2 = a0 + a0;
    wire [11:0] a0_times_2 = (a0_x2 >= Q) ? (a0_x2 - Q) : a0_x2[11:0];
    wire [12:0] a1_x2 = a1 + a1;
    wire [11:0] a1_times_2 = (a1_x2 >= Q) ? (a1_x2 - Q) : a1_x2[11:0];
    wire [11:0] a1_gamma;
    mont_mult mm_twist (.a(a1), .b(gamma), .c(a1_gamma));
    wire [12:0] res0_rr_raw = a0_times_2 + a1_gamma;
    wire [11:0] res0_rr = (res0_rr_raw >= Q) ? (res0_rr_raw - Q) : res0_rr_raw[11:0];
    wire [12:0] res1_rr_raw = a0 + a1_times_2;
    wire [11:0] res1_rr = (res1_rr_raw >= Q) ? (res1_rr_raw - Q) : res1_rr_raw[11:0];
    wire [11:0] twisted_a0 = IS_RRLWE ? res0_rr : (IS_BRMLWE ? a1_gamma : a0);
    wire [11:0] twisted_a1 = IS_RRLWE ? res1_rr : (IS_BRMLWE ? a0 : a1);
    wire [11:0] final_a0 = twist_enable ? twisted_a0 : a0;
    wire [11:0] final_a1 = twist_enable ? twisted_a1 : a1;
    wire [11:0] m_a0_b0, m_a1_b1, m_a1_b1_gamma, m_a0_b1, m_a1_b0;
    mont_mult mm1 (.a(final_a0), .b(b0_raw), .c(m_a0_b0));
    mont_mult mm2 (.a(final_a1), .b(b1_raw), .c(m_a1_b1));
    mont_mult mm3 (.a(m_a1_b1), .b(gamma), .c(m_a1_b1_gamma));
    mont_mult mm4 (.a(final_a0), .b(b1_raw), .c(m_a0_b1));
    mont_mult mm5 (.a(final_a1), .b(b0_raw), .c(m_a1_b0));
    wire [12:0] c0_sum = m_a0_b0 + m_a1_b1_gamma;
    wire [12:0] c1_sum = m_a0_b1 + m_a1_b0;
    wire [11:0] c0_next = (c0_sum >= Q) ? (c0_sum - Q) : c0_sum[11:0];
    wire [11:0] c1_next = (c1_sum >= Q) ? (c1_sum - Q) : c1_sum[11:0];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            done      <= 0;
            i         <= 0;
            out_valid <= 0;
        end else begin
            out_valid <= 0; 
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        i     <= 0;
                        state <= REQ;
                    end
                end
                REQ: begin
                    addr_a0 <= idx_even;
                    addr_a1 <= idx_odd;
                    addr_b0 <= idx_even;
                    addr_b1 <= idx_odd;
                    state   <= WAIT;
                end
                WAIT: begin
                    state <= COMPUTE;
                end
                COMPUTE: begin
                    out_valid <= 1'b1;
                    out_addr0 <= idx_even;
                    out_addr1 <= idx_odd;
                    out_c0    <= c0_next;
                    out_c1    <= c1_next;
                    if (i == 7'd127) begin
                        state <= FINISH; 
                    end else begin
                        i     <= i + 1;
                        state <= REQ;
                    end
                end
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
