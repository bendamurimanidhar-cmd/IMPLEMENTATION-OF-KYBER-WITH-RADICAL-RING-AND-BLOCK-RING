`timescale 1ns / 1ps
module ntt_inverse #(
    parameter Q = 3329
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         done,
    output reg  [7:0]  bram_addrA,
    output reg  [11:0] bram_dinA,
    output reg         bram_weA,
    input  wire [11:0] bram_doutA,
    output reg  [7:0]  bram_addrB,
    output reg  [11:0] bram_dinB,
    output reg         bram_weB,
    input  wire [11:0] bram_doutB
);
    (* rom_style = "block" *) reg [11:0] zeta_rom [0:127];
    initial begin
        zeta_rom[0] = 12'd767;    zeta_rom[1] = 12'd3052;   zeta_rom[2] = 12'd1949;   zeta_rom[3] = 12'd3172;
        zeta_rom[4] = 12'd660;    zeta_rom[5] = 12'd1233;   zeta_rom[6] = 12'd987;    zeta_rom[7] = 12'd134;
        zeta_rom[8] = 12'd2278;   zeta_rom[9] = 12'd2107;   zeta_rom[10] = 12'd2529;  zeta_rom[11] = 12'd3045;
        zeta_rom[12] = 12'd1830;  zeta_rom[13] = 12'd1149;  zeta_rom[14] = 12'd2888;  zeta_rom[15] = 12'd2490;
        zeta_rom[16] = 12'd2382;  zeta_rom[17] = 12'd546;   zeta_rom[18] = 12'd2624;  zeta_rom[19] = 12'd1331;
        zeta_rom[20] = 12'd2653;  zeta_rom[21] = 12'd1824;  zeta_rom[22] = 12'd1047;  zeta_rom[23] = 12'd1154;
        zeta_rom[24] = 12'd2973;  zeta_rom[25] = 12'd606;   zeta_rom[26] = 12'd315;   zeta_rom[27] = 12'd2026;
        zeta_rom[28] = 12'd1152;  zeta_rom[29] = 12'd2939;  zeta_rom[30] = 12'd28;    zeta_rom[31] = 12'd476;
        zeta_rom[32] = 12'd1434;  zeta_rom[33] = 12'd1075;  zeta_rom[34] = 12'd1630;  zeta_rom[35] = 12'd1078;
        zeta_rom[36] = 12'd1681;  zeta_rom[37] = 12'd1945;  zeta_rom[38] = 12'd3104;  zeta_rom[39] = 12'd2833;
        zeta_rom[40] = 12'd1555;  zeta_rom[41] = 12'd3132;  zeta_rom[42] = 12'd3309;  zeta_rom[43] = 12'd2989;
        zeta_rom[44] = 12'd878;   zeta_rom[45] = 12'd1610;  zeta_rom[46] = 12'd738;   zeta_rom[47] = 12'd2559;
        zeta_rom[48] = 12'd226;   zeta_rom[49] = 12'd513;   zeta_rom[50] = 12'd2063;  zeta_rom[51] = 12'd1781;
        zeta_rom[52] = 12'd316;   zeta_rom[53] = 12'd2043;  zeta_rom[54] = 12'd1441;  zeta_rom[55] = 12'd1194;
        zeta_rom[56] = 12'd324;   zeta_rom[57] = 12'd2179;  zeta_rom[58] = 12'd424;   zeta_rom[59] = 12'd550;
        zeta_rom[60] = 12'd2692;  zeta_rom[61] = 12'd2487;  zeta_rom[62] = 12'd2331;  zeta_rom[63] = 12'd3008;
        zeta_rom[64] = 12'd1201;  zeta_rom[65] = 12'd443;   zeta_rom[66] = 12'd873;   zeta_rom[67] = 12'd1525;
        zeta_rom[68] = 12'd2622;  zeta_rom[69] = 12'd1297;  zeta_rom[70] = 12'd2075;  zeta_rom[71] = 12'd1985;
        zeta_rom[72] = 12'd455;   zeta_rom[73] = 12'd1077;  zeta_rom[74] = 12'd1664;  zeta_rom[75] = 12'd1656;
        zeta_rom[76] = 12'd1520;  zeta_rom[77] = 12'd2537;  zeta_rom[78] = 12'd3181;  zeta_rom[79] = 12'd813;
        zeta_rom[80] = 12'd505;   zeta_rom[81] = 12'd1927;  zeta_rom[82] = 12'd2798;  zeta_rom[83] = 12'd960;
        zeta_rom[84] = 12'd3004;  zeta_rom[85] = 12'd1133;  zeta_rom[86] = 12'd2616;  zeta_rom[87] = 12'd1195;
        zeta_rom[88] = 12'd341;   zeta_rom[89] = 12'd2468;  zeta_rom[90] = 12'd2008;  zeta_rom[91] = 12'd846;
        zeta_rom[92] = 12'd1066;  zeta_rom[93] = 12'd1477;  zeta_rom[94] = 12'd1806;  zeta_rom[95] = 12'd741;
        zeta_rom[96] = 12'd2610;  zeta_rom[97] = 12'd1093;  zeta_rom[98] = 12'd1936;  zeta_rom[99] = 12'd2951;
        zeta_rom[100] = 12'd232;  zeta_rom[101] = 12'd615;  zeta_rom[102] = 12'd468;  zeta_rom[103] = 12'd1298;
        zeta_rom[104] = 12'd2092; zeta_rom[105] = 12'd2274; zeta_rom[106] = 12'd2039; zeta_rom[107] = 12'd1373;
        zeta_rom[108] = 12'd38;   zeta_rom[109] = 12'd646;  zeta_rom[110] = 12'd995;  zeta_rom[111] = 12'd270;
        zeta_rom[112] = 12'd1261; zeta_rom[113] = 12'd1463; zeta_rom[114] = 12'd1568; zeta_rom[115] = 12'd24;
        zeta_rom[116] = 12'd408;  zeta_rom[117] = 12'd278;  zeta_rom[118] = 12'd1397; zeta_rom[119] = 12'd446;
        zeta_rom[120] = 12'd924;  zeta_rom[121] = 12'd2392; zeta_rom[122] = 12'd716;  zeta_rom[123] = 12'd2185;
        zeta_rom[124] = 12'd526;  zeta_rom[125] = 12'd2284; zeta_rom[126] = 12'd2209; zeta_rom[127] = 12'd934;
    end
    localparam IDLE          = 3'd0;
    localparam REQ           = 3'd1;  
    localparam WAIT          = 3'd2;
    localparam COMPUTE       = 3'd3;  
    localparam SCALE_REQ     = 3'd4;  
    localparam SCALE_WAIT    = 3'd5;
    localparam SCALE_COMPUTE = 3'd6;
    localparam FINISH        = 3'd7;
    reg [2:0] state;
    reg [2:0] layer;       
    reg [8:0] start_idx;   
    reg [7:0] j_idx;       
    reg [6:0] k_idx;       
    reg [6:0] scale_idx;   
    wire [8:0] current_len = 9'd2 << layer; 
    wire [7:0] index_even = start_idx + j_idx;
    wire [7:0] index_odd  = start_idx + j_idx + current_len;
    wire [11:0] a_val = bram_doutA;
    wire [11:0] b_val = bram_doutB;
    wire [6:0] rev_k = {k_idx[0], k_idx[1], k_idx[2], k_idx[3], k_idx[4], k_idx[5], k_idx[6]};
    wire [11:0] zeta  = zeta_rom[rev_k];
    wire [12:0] sum_raw = a_val + b_val;
    wire [11:0] a_new   = (sum_raw >= Q) ? (sum_raw - Q) : sum_raw[11:0];
    wire [11:0] diff_raw = (b_val < a_val) ? (b_val + Q - a_val) : (b_val - a_val);
    wire [11:0] b_new;
    mont_mult #(
        .Q(Q), .Q_inv(3327), .rsh(12)
    ) mont_inst_intt (
        .a(zeta),
        .b(diff_raw),
        .c(b_new)
    );
    wire [11:0] scale_outA, scale_outB;
    mont_mult #(
        .Q(Q), .Q_inv(3327), .rsh(12)
    ) mm_scaleA (
        .a(12'd32),
        .b(bram_doutA),
        .c(scale_outA)
    );
    mont_mult #(
        .Q(Q), .Q_inv(3327), .rsh(12)
    ) mm_scaleB (
        .a(12'd32),
        .b(bram_doutB),
        .c(scale_outB)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            done       <= 0;
            layer      <= 0;
            start_idx  <= 0;
            j_idx      <= 0;
            k_idx      <= 0;
            scale_idx  <= 0;
            bram_weA   <= 0;
            bram_weB   <= 0;
        end else begin
            bram_weA <= 0;
            bram_weB <= 0;
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        layer     <= 0;
                        start_idx <= 0;
                        j_idx     <= 0;
                        k_idx     <= 7'd127; 
                        scale_idx <= 0;
                        state     <= REQ;
                    end
                end
                REQ: begin
                    bram_addrA <= index_even;
                    bram_addrB <= index_odd;
                    state      <= WAIT;
                end
                WAIT: begin
                    state <= COMPUTE;
                end
                COMPUTE: begin
                    bram_dinA  <= a_new;
                    bram_dinB  <= b_new;
                    bram_weA   <= 1'b1;
                    bram_weB   <= 1'b1;
                    if (j_idx == current_len - 1) begin
                        j_idx <= 0;
                        k_idx <= k_idx - 1'b1; 
                        if (start_idx + (current_len << 1) >= 256) begin
                            start_idx <= 0;
                            if (layer == 6) begin
                                state <= SCALE_REQ; 
                            end else begin
                                layer <= layer + 1;
                                state <= REQ;
                            end
                        end else begin
                            start_idx <= start_idx + (current_len << 1);
                            state <= REQ;
                        end
                    end else begin
                        j_idx <= j_idx + 1;
                        state <= REQ;
                    end
                end
                SCALE_REQ: begin
                    bram_addrA <= {scale_idx, 1'b0};
                    bram_addrB <= {scale_idx, 1'b1};
                    state      <= SCALE_WAIT;
                end
                SCALE_WAIT: begin
                    state <= SCALE_COMPUTE;
                end
                SCALE_COMPUTE: begin
                    bram_dinA <= scale_outA;
                    bram_dinB <= scale_outB;
                    bram_weA  <= 1'b1;
                    bram_weB  <= 1'b1;
                    if (scale_idx == 7'd127) begin
                        state <= FINISH;
                    end else begin
                        scale_idx <= scale_idx + 1'b1;
                        state     <= SCALE_REQ;
                    end
                end
                FINISH: begin
                    done  <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
