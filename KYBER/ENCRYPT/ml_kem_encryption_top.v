`timescale 1ns / 1ps
module mlkem_encrypt_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         ready,
    output reg         done,
    input  wire [255:0] m_in, 
    input  wire [255:0] r_in, 
    output wire [8:0]  ek_rd_addr,
    input  wire [23:0] ek_rd_data,
    input  wire [9:0]  c_rd_addr, 
    output wire [11:0] c_rd_data
);
    localparam [7:0] K_PARAM = 8'd3;   
    localparam [7:0] K_LAST  = K_PARAM - 8'd1;  
    localparam [11:0] MATRIX_LEN = {4'd0, K_PARAM} * {4'd0, K_PARAM} * 12'd256; 
    localparam [9:0]  VEC_LEN    = {2'd0, K_PARAM} * 10'd256;                   
    localparam [9:0]  U_LEN      = VEC_LEN;                                     
    localparam [8:0]  RHO_OFFSET = K_PARAM * 9'd128;                            
    localparam STATE_IDLE           = 5'd0;
    localparam STATE_READ_RHO_ADDR  = 5'd1;  
    localparam WAIT                 = 5'd2;
    localparam STATE_READ_RHO_DATA  = 5'd3;
    localparam STATE_GEN_MATRIX     = 5'd4;  
    localparam STATE_PROCESS_REJ    = 5'd5;  
    localparam STATE_SQUEEZE_MATRIX = 5'd6;  
    localparam STATE_GEN_VECTORS    = 5'd7;  
    localparam STATE_SAVE_VECTORS   = 5'd8;
    localparam STATE_NTT_Y_LOAD     = 5'd9;  
    localparam STATE_NTT_Y_WAIT     = 5'd10;
    localparam STATE_MAC_U_LOAD     = 5'd11; 
    localparam STATE_MAC_U_WAIT     = 5'd12;
    localparam STATE_INTT_U_LOAD    = 5'd13; 
    localparam STATE_INTT_U_WAIT    = 5'd14;
    localparam STATE_ADD_E1_REQ     = 5'd15; 
    localparam STATE_ADD_E1_WAIT    = 5'd16;
    localparam STATE_ADD_E1_COMPUTE = 5'd17;
    localparam STATE_MAC_V_LOAD     = 5'd18; 
    localparam STATE_MAC_V_WAIT     = 5'd19;
    localparam STATE_INTT_V_LOAD    = 5'd20; 
    localparam STATE_INTT_V_WAIT    = 5'd21;
    localparam STATE_ADD_E2_REQ     = 5'd22; 
    localparam STATE_ADD_E2_WAIT    = 5'd23;
    localparam STATE_ADD_E2_COMPUTE = 5'd24;
    localparam STATE_COMPRESS_U     = 5'd25; 
    localparam STATE_COMPRESS_V     = 5'd26; 
    localparam STATE_DONE           = 5'd27;
    (* fsm_encoding = "gray" *) reg [4:0] current_state; 
    reg [255:0] rho_reg;
    reg [255:0] r_reg;
    reg [255:0] m_reg;
    reg [3:0]   rho_rd_idx;
    reg [7:0]   i_idx_reg;
    reg [7:0]   j_idx_reg;
    reg [7:0]   nonce_reg;
    reg [9:0]   coeff_counter;
    reg [7:0]   bitstream_count;
    reg  [1:0]  poly_idx_reg;
    reg [8:0]   seq_ek_rd_addr;
    reg         wr_en_pipe;
    reg [9:0]   wr_addr_pipe;
    reg  cmd_gen_matrix;
    reg  cmd_gen_vector;
    reg  cmd_squeeze_more;
    wire keccak_ready;
    wire keccak_valid;
    wire [1343:0] shake_out;
    wire [23:0] current_3_bytes = shake_out[(bitstream_count * 8) +: 24];
    wire [11:0] d1, d2;
    wire        d1_valid, d2_valid;
    wire [11:0] base_idx = (current_state == STATE_PROCESS_REJ) ? 
                          ((({4'd0,i_idx_reg} * {4'd0,K_PARAM}) + {4'd0,j_idx_reg}) * 12'd256) : 
                          ((({4'd0,j_idx_reg} * {4'd0,K_PARAM}) + {4'd0,i_idx_reg}) * 12'd256);
    wire hit_256 = (coeff_counter >= 9'd256) ||
                   (coeff_counter == 9'd255 &&  d1_valid             ) ||
                   (coeff_counter == 9'd254 &&  d1_valid && d2_valid) ||
                   (coeff_counter == 9'd255 && !d1_valid && d2_valid);
    reg         ntt_start;
    wire        ntt_done;
    wire [7:0]  ntt_bram_addrA, ntt_bram_addrB;
    wire [11:0] ntt_bram_dinA,  ntt_bram_dinB;
    wire        ntt_bram_weA,   ntt_bram_weB;
    reg         dot_start;
    wire        dot_done;
    wire        dot_out_valid;
    wire [7:0]  dot_out_addr0, dot_out_addr1;
    wire [11:0] dot_out_c0,    dot_out_c1;
    wire [7:0]  dot_addr_a0, dot_addr_a1;
    wire [7:0]  dot_addr_b0, dot_addr_b1;
    reg         intt_start;
    wire        intt_done;
    wire [7:0]  intt_bram_addrA, intt_bram_addrB;
    wire [11:0] intt_bram_dinA,  intt_bram_dinB;
    wire        intt_bram_weA,   intt_bram_weB;
    wire [9:0] ntt_full_addrA  = {poly_idx_reg, ntt_bram_addrA};
    wire [9:0] ntt_full_addrB  = {poly_idx_reg, ntt_bram_addrB};
    wire [9:0] intt_full_addrA = {poly_idx_reg, intt_bram_addrA};
    wire [9:0] intt_full_addrB = {poly_idx_reg, intt_bram_addrB};
    wire is_intt_u = (current_state == STATE_INTT_U_LOAD || current_state == STATE_INTT_U_WAIT);
    wire is_intt_v = (current_state == STATE_INTT_V_LOAD || current_state == STATE_INTT_V_WAIT);
    assign ek_rd_addr = (current_state == STATE_MAC_V_WAIT || current_state == STATE_MAC_V_LOAD) ? 
                        ((i_idx_reg * 9'd128) + {2'b00, dot_addr_a0[7:1]}) : seq_ek_rd_addr;
    wire [11:0] t_coeff0 = {ek_rd_data[11:8], ek_rd_data[7:0]};
    wire [11:0] t_coeff1 = {ek_rd_data[23:16], ek_rd_data[15:12]};
    wire [11:0] bram_A_addrA, bram_A_addrB;
    wire [11:0] bram_A_dinA,  bram_A_dinB;
    wire        bram_A_weA,   bram_A_weB;
    wire [11:0] bram_A_doutA, bram_A_doutB;
    assign bram_A_addrA = (current_state == STATE_PROCESS_REJ) ? (base_idx + {2'b0, coeff_counter}) : 
                                                                 (base_idx + {4'b0, dot_addr_a0});
    assign bram_A_dinA  = d1_valid ? d1 : d2;
    assign bram_A_weA   = (current_state == STATE_PROCESS_REJ) && (d1_valid || d2_valid) && (coeff_counter < 9'd256);
    assign bram_A_addrB = (current_state == STATE_PROCESS_REJ) ? (base_idx + {2'b0, coeff_counter} + 12'd1) : 
                                                                 (base_idx + {4'b0, dot_addr_a1});
    assign bram_A_dinB  = d2;
    assign bram_A_weB   = (current_state == STATE_PROCESS_REJ) && d1_valid && d2_valid && (coeff_counter < 9'd255);
    tdp_bram_2304x12 mem_A (
        .clk(clk), .addrA(bram_A_addrA), .dinA(bram_A_dinA), .weA(bram_A_weA), .doutA(bram_A_doutA),
        .addrB(bram_A_addrB), .dinB(bram_A_dinB), .weB(bram_A_weB), .doutB(bram_A_doutB)
    );
    wire [1:0] nonce_sub_idx = (nonce_reg < K_PARAM) ? nonce_reg[1:0] : (nonce_reg - K_PARAM);
    wire [9:0] vector_flat_addr = ({8'd0, nonce_sub_idx} * 10'd256) + coeff_counter[9:0];
    wire [3:0]  cbd_in_bits = shake_out[(coeff_counter * 4) +: 4];
    wire        cbd_is_secret = (nonce_reg < K_PARAM) ? 1'b1 : 1'b0; 
    wire [11:0] cbd_coeff_out;
    wire we_y = (current_state == STATE_SAVE_VECTORS) && (nonce_reg < K_PARAM);
    wire [9:0]  bram_y_addrA = (current_state == STATE_NTT_Y_WAIT) ? ntt_full_addrA :
                               (current_state == STATE_MAC_U_WAIT) ? {j_idx_reg[1:0], dot_addr_b0} : 
                               (current_state == STATE_MAC_V_WAIT) ? {i_idx_reg[1:0], dot_addr_b0} : vector_flat_addr;
    wire [11:0] bram_y_dinA  = (current_state == STATE_NTT_Y_WAIT) ? ntt_bram_dinA  : cbd_coeff_out;
    wire        bram_y_weA   = we_y || (current_state == STATE_NTT_Y_WAIT && ntt_bram_weA);
    wire [9:0]  bram_y_addrB = (current_state == STATE_NTT_Y_WAIT) ? ntt_full_addrB :
                               (current_state == STATE_MAC_U_WAIT) ? {j_idx_reg[1:0], dot_addr_b1} : 
                               (current_state == STATE_MAC_V_WAIT) ? {i_idx_reg[1:0], dot_addr_b1} : 10'd0;
    wire [11:0] bram_y_dinB  = ntt_bram_dinB;
    wire        bram_y_weB   = (current_state == STATE_NTT_Y_WAIT && ntt_bram_weB);
    wire [11:0] bram_y_doutA, bram_y_doutB;
    tdp_bram_768x12 mem_y (
        .clk(clk), .addrA(bram_y_addrA), .dinA(bram_y_dinA), .weA(bram_y_weA), .doutA(bram_y_doutA), 
        .addrB(bram_y_addrB), .dinB(bram_y_dinB), .weB(bram_y_weB), .doutB(bram_y_doutB)
    );
    wire [9:0] add_addrA = {poly_idx_reg, coeff_counter[6:0], 1'b0};
    wire [9:0] add_addrB = {poly_idx_reg, coeff_counter[6:0], 1'b1};
    wire we_e1 = (current_state == STATE_SAVE_VECTORS) && (nonce_reg >= K_PARAM) && (nonce_reg < (K_PARAM + K_PARAM));
    wire [9:0]  bram_e1_addrA = (current_state == STATE_SAVE_VECTORS) ? vector_flat_addr : add_addrA;
    wire [11:0] bram_e1_dinA  = cbd_coeff_out;
    wire        bram_e1_weA   = we_e1;
    wire [11:0] bram_e1_doutA, bram_e1_doutB;
    tdp_bram_768x12 mem_e1 (
        .clk(clk), .addrA(bram_e1_addrA), .dinA(bram_e1_dinA), .weA(bram_e1_weA), .doutA(bram_e1_doutA),
        .addrB((current_state >= STATE_ADD_E1_REQ) ? add_addrB : 10'd0), 
        .dinB(12'd0), .weB(1'b0), .doutB(bram_e1_doutB) 
    );
    wire we_e2 = (current_state == STATE_SAVE_VECTORS) && (nonce_reg == (K_PARAM + K_PARAM));
    wire [7:0]  bram_e2_addrA = (current_state == STATE_SAVE_VECTORS) ? coeff_counter[7:0] : add_addrA[7:0];
    wire [11:0] bram_e2_dinA  = cbd_coeff_out;
    wire        bram_e2_weA   = we_e2;
    wire [11:0] bram_e2_doutA, bram_e2_doutB;
    tdp_bram_256x12 mem_e2 (
        .clk(clk), .addrA(bram_e2_addrA), .dinA(bram_e2_dinA), .weA(bram_e2_weA), .doutA(bram_e2_doutA),
        .addrB((current_state >= STATE_ADD_E2_REQ) ? add_addrB[7:0] : 8'd0), 
        .dinB(12'd0), .weB(1'b0), .doutB(bram_e2_doutB)
    );
    wire [9:0]  bram_u_acc_addrA, bram_u_acc_addrB;
    wire [11:0] bram_u_acc_dinA,  bram_u_acc_dinB;
    wire        bram_u_acc_weA,   bram_u_acc_weB;
    wire [11:0] bram_u_acc_doutA, bram_u_acc_doutB;
    wire j_is_first = (j_idx_reg == 8'd0);
    wire j_is_last  = (j_idx_reg == K_LAST);
    wire i_is_last  = (i_idx_reg == K_LAST);
    wire [9:0]  bram_u_vec_addrA, bram_u_vec_addrB;
    wire [11:0] bram_u_vec_dinA,  bram_u_vec_dinB;
    wire        bram_u_vec_weA,   bram_u_vec_weB;
    wire [11:0] bram_u_vec_doutA, bram_u_vec_doutB;
    wire [7:0]  bram_v_acc_addrA, bram_v_acc_addrB;
    wire [11:0] bram_v_acc_dinA,  bram_v_acc_dinB;
    wire        bram_v_acc_weA,   bram_v_acc_weB;
    wire [11:0] bram_v_acc_doutA, bram_v_acc_doutB;
    wire [12:0] u_mac_add0 = bram_u_acc_doutA + dot_out_c0;
    wire [11:0] u_mac_mod0 = (u_mac_add0 >= 13'd3329) ? (u_mac_add0 - 13'd3329) : u_mac_add0[11:0];
    wire [12:0] u_mac_add1 = bram_u_acc_doutB + dot_out_c1;
    wire [11:0] u_mac_mod1 = (u_mac_add1 >= 13'd3329) ? (u_mac_add1 - 13'd3329) : u_mac_add1[11:0];
    wire [12:0] u_e1_add0 = bram_u_vec_doutA + bram_e1_doutA;
    wire [11:0] u_e1_mod0 = (u_e1_add0 >= 13'd3329) ? (u_e1_add0 - 13'd3329) : u_e1_add0[11:0];
    wire [12:0] u_e1_add1 = bram_u_vec_doutB + bram_e1_doutB;
    wire [11:0] u_e1_mod1 = (u_e1_add1 >= 13'd3329) ? (u_e1_add1 - 13'd3329) : u_e1_add1[11:0];
    wire [12:0] v_mac_add0 = bram_v_acc_doutA + dot_out_c0;
    wire [11:0] v_mac_mod0 = (v_mac_add0 >= 13'd3329) ? (v_mac_add0 - 13'd3329) : v_mac_add0[11:0];
    wire [12:0] v_mac_add1 = bram_v_acc_doutB + dot_out_c1;
    wire [11:0] v_mac_mod1 = (v_mac_add1 >= 13'd3329) ? (v_mac_add1 - 13'd3329) : v_mac_add1[11:0];
    wire [7:0] m_bit_idx0 = 8'd248 - {add_addrA[7:3], 3'd0} + add_addrA[2:0];
    wire [7:0] m_bit_idx1 = 8'd248 - {add_addrB[7:3], 3'd0} + add_addrB[2:0];
    wire [11:0] mu_coeff0 = m_reg[m_bit_idx0] ? 12'd1665 : 12'd0;
    wire [11:0] mu_coeff1 = m_reg[m_bit_idx1] ? 12'd1665 : 12'd0;
    wire [13:0] v_final_add0 = bram_v_acc_doutA + bram_e2_doutA + mu_coeff0;
    wire [13:0] v_sub1_0 = v_final_add0 - 14'd3329;
    wire [13:0] v_sub2_0 = v_sub1_0 - 14'd3329;
    wire [11:0] v_final_mod0 = (v_final_add0 < 14'd3329) ? v_final_add0[11:0] :
                               (v_sub1_0 < 14'd3329)     ? v_sub1_0[11:0]     : v_sub2_0[11:0];
    wire [13:0] v_final_add1 = bram_v_acc_doutB + bram_e2_doutB + mu_coeff1;
    always @(posedge clk) if (current_state == STATE_ADD_E2_COMPUTE && coeff_counter < 16) $display("coeff_counter=%0d, bram_v_acc_doutA=%0d, bram_e2_doutA=%0d, mu_coeff0=%0d, v_final_add0=%0d", coeff_counter, bram_v_acc_doutA, bram_e2_doutA, mu_coeff0, v_final_add0);
    wire [13:0] v_sub1_1 = v_final_add1 - 14'd3329;
    wire [13:0] v_sub2_1 = v_sub1_1 - 14'd3329;
    wire [11:0] v_final_mod1 = (v_final_add1 < 14'd3329) ? v_final_add1[11:0] :
                               (v_sub1_1 < 14'd3329)     ? v_sub1_1[11:0]     : v_sub2_1[11:0];
    wire [21:0] u_mul = {bram_u_vec_doutB, 10'd0}; 
    wire [21:0] u_add = u_mul + 22'd1664;
    (* use_dsp = "yes" *) wire [21:0] u_div = u_add / 22'd3329; 
    wire [9:0]  comp_u = u_div[9:0];
    wire [15:0] v_mul = {bram_v_acc_doutB, 4'd0};
    wire [15:0] v_add = v_mul + 16'd1664;
    (* use_dsp = "yes" *) wire [15:0] v_div = v_add / 16'd3329; 
    wire [3:0]  comp_v = v_div[3:0];
    always @(posedge clk) if (current_state == STATE_COMPRESS_V && coeff_counter < 10) $display("COMPRESS_V: coeff_counter=%0d, wr_en=%b, wr_addr=%0d, doutB=%0d, comp_v=%0d", coeff_counter, wr_en_pipe, wr_addr_pipe, bram_v_acc_doutB, comp_v);
    assign bram_u_acc_addrA = j_is_first ? {i_idx_reg[1:0], dot_out_addr0} : {i_idx_reg[1:0], dot_addr_a0};
    assign bram_u_acc_dinA  = j_is_first ? dot_out_c0 : u_mac_mod0;
    assign bram_u_acc_weA   = dot_out_valid && !j_is_last && (current_state == STATE_MAC_U_WAIT);
    assign bram_u_acc_addrB = j_is_first ? {i_idx_reg[1:0], dot_out_addr1} : {i_idx_reg[1:0], dot_addr_a1};
    assign bram_u_acc_dinB  = j_is_first ? dot_out_c1 : u_mac_mod1;
    assign bram_u_acc_weB   = dot_out_valid && !j_is_last && (current_state == STATE_MAC_U_WAIT);
    tdp_bram_768x12 mem_u_acc (
        .clk(clk), .addrA(bram_u_acc_addrA), .dinA(bram_u_acc_dinA), .weA(bram_u_acc_weA), .doutA(bram_u_acc_doutA),
        .addrB(bram_u_acc_addrB), .dinB(bram_u_acc_dinB), .weB(bram_u_acc_weB), .doutB(bram_u_acc_doutB)
    );
    assign bram_u_vec_addrA = (current_state == STATE_COMPRESS_U) ? wr_addr_pipe :
                              (current_state == STATE_MAC_U_WAIT) ? {i_idx_reg[1:0], dot_out_addr0} :
                              (is_intt_u)                         ? intt_full_addrA : add_addrA;
    assign bram_u_vec_dinA  = (current_state == STATE_COMPRESS_U) ? {2'b00, comp_u} :
                              (current_state == STATE_MAC_U_WAIT) ? u_mac_mod0 :
                              (is_intt_u)                         ? intt_bram_dinA : u_e1_mod0;
    assign bram_u_vec_weA   = (current_state == STATE_COMPRESS_U) ? wr_en_pipe :
                              (current_state == STATE_MAC_U_WAIT) ? (dot_out_valid && j_is_last) :
                              (is_intt_u)                         ? intt_bram_weA :
                              (current_state == STATE_ADD_E1_COMPUTE);
    assign bram_u_vec_addrB = (current_state == STATE_DONE)       ? c_rd_addr[9:0] :
                              (current_state == STATE_COMPRESS_U) ? coeff_counter[9:0] :
                              (current_state == STATE_MAC_U_WAIT) ? {i_idx_reg[1:0], dot_out_addr1} :
                              (is_intt_u)                         ? intt_full_addrB : add_addrB;
    assign bram_u_vec_dinB  = (current_state == STATE_MAC_U_WAIT) ? u_mac_mod1 :
                              (is_intt_u)                         ? intt_bram_dinB : u_e1_mod1;
    assign bram_u_vec_weB   = (current_state == STATE_MAC_U_WAIT) ? (dot_out_valid && j_is_last) :
                              (is_intt_u)                         ? intt_bram_weB :
                              (current_state == STATE_ADD_E1_COMPUTE);
    tdp_bram_768x12 mem_u_vec (
        .clk(clk), .addrA(bram_u_vec_addrA), .dinA(bram_u_vec_dinA), .weA(bram_u_vec_weA), .doutA(bram_u_vec_doutA),
        .addrB(bram_u_vec_addrB), .dinB(bram_u_vec_dinB), .weB(bram_u_vec_weB), .doutB(bram_u_vec_doutB)
    );
    assign bram_v_acc_addrA = (current_state == STATE_COMPRESS_V) ? wr_addr_pipe[7:0] :
                              (current_state == STATE_MAC_V_WAIT) ? ((i_idx_reg == 0) ? dot_out_addr0 : dot_addr_a0) :
                              (is_intt_v)                         ? intt_bram_addrA : add_addrA[7:0];
    assign bram_v_acc_dinA  = (current_state == STATE_COMPRESS_V) ? {8'b00000000, comp_v} :
                              (current_state == STATE_MAC_V_WAIT) ? ((i_idx_reg == 0) ? dot_out_c0 : v_mac_mod0) :
                              (is_intt_v)                         ? intt_bram_dinA : v_final_mod0;
    assign bram_v_acc_weA   = (current_state == STATE_COMPRESS_V) ? wr_en_pipe :
                              (current_state == STATE_MAC_V_WAIT) ? dot_out_valid :
                              (is_intt_v)                         ? intt_bram_weA : (current_state == STATE_ADD_E2_COMPUTE);
    assign bram_v_acc_addrB = (current_state == STATE_DONE)       ? (c_rd_addr - 10'd768) :
                              (current_state == STATE_COMPRESS_V) ? coeff_counter[7:0] :
                              (current_state == STATE_MAC_V_WAIT) ? ((i_idx_reg == 0) ? dot_out_addr1 : dot_addr_a1) :
                              (is_intt_v)                         ? intt_bram_addrB : add_addrB[7:0];
    assign bram_v_acc_dinB  = (current_state == STATE_MAC_V_WAIT) ? ((i_idx_reg == 0) ? dot_out_c1 : v_mac_mod1) :
                              (is_intt_v)                         ? intt_bram_dinB : v_final_mod1;
    assign bram_v_acc_weB   = (current_state == STATE_MAC_V_WAIT) ? dot_out_valid :
                              (is_intt_v)                         ? intt_bram_weB : (current_state == STATE_ADD_E2_COMPUTE);
    tdp_bram_256x12 mem_v_acc (
        .clk(clk), .addrA(bram_v_acc_addrA), .dinA(bram_v_acc_dinA), .weA(bram_v_acc_weA), .doutA(bram_v_acc_doutA),
        .addrB(bram_v_acc_addrB), .dinB(bram_v_acc_dinB), .weB(bram_v_acc_weB), .doutB(bram_v_acc_doutB)
    );
    assign c_rd_data = (c_rd_addr < 10'd768) ? bram_u_vec_doutB : bram_v_acc_doutB;
    kyber_keccak_wrapper u_keccak (
        .clk(clk), .rst_n(rst_n), .cmd_hash_seed(1'b0), .cmd_gen_vector(cmd_gen_vector), 
        .cmd_gen_matrix(cmd_gen_matrix), .cmd_squeeze_more(cmd_squeeze_more), .seed_in(256'd0), 
        .k_param(K_PARAM), .sigma(r_reg), .nonce(nonce_reg), .rho(rho_reg), .i_idx(i_idx_reg),
        .j_idx(j_idx_reg), .ready(keccak_ready), .dout_valid(keccak_valid), .sha3_out(), .shake_out(shake_out)
    );
    kyber_parse u_parser (
        .bytes_in(current_3_bytes), .coeff1(d1), .coeff2(d2),
        .coeff1_valid(d1_valid), .coeff2_valid(d2_valid)
    );
    cbd_eta2 u_cbd (
        .prf_bits(cbd_in_bits), .is_secret(cbd_is_secret), .coeff_out(cbd_coeff_out)
    );
    ntt_forward #(.Q(3329)) u_ntt_y (
        .clk(clk), .rst_n(rst_n), .start(ntt_start), .done(ntt_done),
        .bram_addrA(ntt_bram_addrA), .bram_dinA(ntt_bram_dinA), .bram_weA(ntt_bram_weA), .bram_doutA(bram_y_doutA),
        .bram_addrB(ntt_bram_addrB), .bram_dinB(ntt_bram_dinB), .bram_weB(ntt_bram_weB), .bram_doutB(bram_y_doutB)
    );
    ntt_dot_prod #(.Q(3329)) u_dot (
        .clk(clk), .rst_n(rst_n), .start(dot_start), .done(dot_done),
        .addr_a0(dot_addr_a0), .addr_a1(dot_addr_a1),
        .dout_a0( (current_state == STATE_MAC_U_WAIT) ? bram_A_doutA : t_coeff0 ),
        .dout_a1( (current_state == STATE_MAC_U_WAIT) ? bram_A_doutB : t_coeff1 ),
        .addr_b0(dot_addr_b0), .addr_b1(dot_addr_b1),
        .dout_b0(bram_y_doutA), .dout_b1(bram_y_doutB),
        .out_valid(dot_out_valid), .out_addr0(dot_out_addr0), .out_addr1(dot_out_addr1),
        .out_c0(dot_out_c0), .out_c1(dot_out_c1)
    );
    ntt_inverse #(.Q(3329)) u_intt (
        .clk(clk), .rst_n(rst_n), .start(intt_start), .done(intt_done),
        .bram_addrA(intt_bram_addrA), .bram_dinA(intt_bram_dinA), .bram_weA(intt_bram_weA),
        .bram_doutA( is_intt_u ? bram_u_vec_doutA : bram_v_acc_doutA ),
        .bram_addrB(intt_bram_addrB), .bram_dinB(intt_bram_dinB), .bram_weB(intt_bram_weB),
        .bram_doutB( is_intt_u ? bram_u_vec_doutB : bram_v_acc_doutB )
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state    <= STATE_IDLE;
            ready            <= 1'b1;
            done             <= 1'b0;
            rho_reg          <= 256'd0;
            r_reg            <= 256'd0;
            m_reg            <= 256'd0;
            rho_rd_idx       <= 4'd0;
            i_idx_reg        <= 8'd0;
            j_idx_reg        <= 8'd0;
            nonce_reg        <= 8'd0;
            coeff_counter    <= 9'd0;
            bitstream_count  <= 8'd0;
            poly_idx_reg     <= 1'b0;
            seq_ek_rd_addr   <= 9'd0;
            cmd_gen_matrix   <= 1'b0;
            cmd_gen_vector   <= 1'b0;
            cmd_squeeze_more <= 1'b0;
            ntt_start        <= 1'b0;
            dot_start        <= 1'b0;
            intt_start       <= 1'b0;
        end else begin
            cmd_gen_matrix   <= 1'b0;
            cmd_gen_vector   <= 1'b0;
            cmd_squeeze_more <= 1'b0;
            ntt_start        <= 1'b0;
            dot_start        <= 1'b0;
            intt_start       <= 1'b0;
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start && keccak_ready) begin
                        r_reg          <= r_in; 
                        m_reg          <= m_in; 
                        rho_rd_idx     <= 4'd0;
                        ready          <= 1'b0;
                        seq_ek_rd_addr <= 9'd0;
                        current_state  <= STATE_READ_RHO_ADDR;
                    end
                end
                STATE_READ_RHO_ADDR: begin
                    seq_ek_rd_addr <= RHO_OFFSET;
                    current_state  <= WAIT;
                end
                WAIT: begin
                    seq_ek_rd_addr <= RHO_OFFSET + 9'd1;
                    current_state  <= STATE_READ_RHO_DATA;
                end
                STATE_READ_RHO_DATA: begin
                    if (rho_rd_idx < 4'd10) begin
                        rho_reg[255 - (rho_rd_idx * 8'd24) -: 24] <= {ek_rd_data[7:0], ek_rd_data[15:8], ek_rd_data[23:16]};
                    end else begin
                        rho_reg[15:0] <= {ek_rd_data[7:0], ek_rd_data[15:8]};
                    end
                    seq_ek_rd_addr <= RHO_OFFSET + {5'd0, rho_rd_idx} + 9'd2;
                    if (rho_rd_idx == 4'd10) begin
                        i_idx_reg      <= 8'd0;
                        j_idx_reg      <= 8'd0;
                        current_state  <= STATE_GEN_MATRIX;
                        cmd_gen_matrix <= 1'b1; 
                    end else begin
                        rho_rd_idx    <= rho_rd_idx + 1'b1;
                        current_state <= STATE_READ_RHO_DATA;
                    end
                end
                STATE_GEN_MATRIX: begin
                    if (keccak_valid) begin
                        bitstream_count <= 8'd0;
                        coeff_counter   <= 9'd0;
                        current_state   <= STATE_PROCESS_REJ;
                    end
                end
                STATE_PROCESS_REJ: begin
                    if (d1_valid && d2_valid) begin
                        if (coeff_counter < 9'd255) coeff_counter <= coeff_counter + 9'd2;
                        else if (coeff_counter == 9'd255) coeff_counter <= 9'd256;
                    end
                    else if (d1_valid && coeff_counter < 9'd256) coeff_counter <= coeff_counter + 9'd1;
                    else if (d2_valid && coeff_counter < 9'd256) coeff_counter <= coeff_counter + 9'd1;
                    if (hit_256) begin
                        if (j_idx_reg == K_LAST) begin
                            j_idx_reg <= 8'd0;
                            if (i_idx_reg == K_LAST) begin
                                nonce_reg      <= 8'd0;
                                current_state  <= STATE_GEN_VECTORS; 
                                cmd_gen_vector <= 1'b1; 
                            end else begin
                                i_idx_reg      <= i_idx_reg + 1'b1;
                                current_state  <= STATE_GEN_MATRIX;
                                cmd_gen_matrix <= 1'b1; 
                            end
                        end else begin
                            j_idx_reg      <= j_idx_reg + 1'b1;
                            current_state  <= STATE_GEN_MATRIX;
                            cmd_gen_matrix <= 1'b1; 
                        end
                    end
                    else if (bitstream_count >= 8'd165) begin
                        current_state    <= STATE_SQUEEZE_MATRIX;
                        cmd_squeeze_more <= 1'b1; 
                    end
                    else bitstream_count <= bitstream_count + 8'd3;
                end
                STATE_SQUEEZE_MATRIX: begin
                    if (keccak_valid) begin
                        bitstream_count <= 8'd0;
                        current_state   <= STATE_PROCESS_REJ;
                    end
                end
                STATE_GEN_VECTORS: begin
                    if (keccak_valid) begin
                        coeff_counter <= 9'd0;
                        current_state <= STATE_SAVE_VECTORS;
                    end
                end
                STATE_SAVE_VECTORS: begin
                    if (coeff_counter == 9'd255) begin
                        if (nonce_reg == (K_PARAM + K_PARAM)) begin 
                            current_state <= STATE_NTT_Y_LOAD;
                            poly_idx_reg  <= 2'd0;
                        end else begin
                            nonce_reg      <= nonce_reg + 1'b1;
                            current_state  <= STATE_GEN_VECTORS;
                            cmd_gen_vector <= 1'b1; 
                        end
                    end else coeff_counter <= coeff_counter + 1'b1;
                end
                STATE_NTT_Y_LOAD: begin
                    ntt_start     <= 1'b1;
                    current_state <= STATE_NTT_Y_WAIT;
                end
                STATE_NTT_Y_WAIT: begin
                    if (ntt_done) begin                        
                        if (poly_idx_reg == K_LAST[1:0]) begin 
                            current_state <= STATE_MAC_U_LOAD; 
                            i_idx_reg     <= 8'd0;
                            j_idx_reg     <= 8'd0;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 2'd1;
                            current_state <= STATE_NTT_Y_LOAD;
                        end
                    end
                end
                STATE_MAC_U_LOAD: begin
                    dot_start     <= 1'b1; 
                    current_state <= STATE_MAC_U_WAIT;
                end
                STATE_MAC_U_WAIT: begin
                    if (dot_done) begin
                        if (j_idx_reg == K_LAST) begin
                            if (i_idx_reg == K_LAST) begin 
                                current_state <= STATE_INTT_U_LOAD;
                                poly_idx_reg  <= 2'd0;
                            end else begin
                                i_idx_reg     <= i_idx_reg + 1'b1;
                                j_idx_reg     <= 8'd0;
                                current_state <= STATE_MAC_U_LOAD;
                            end
                        end else begin
                            j_idx_reg     <= j_idx_reg + 1'b1;
                            current_state <= STATE_MAC_U_LOAD;
                        end
                    end
                end
                STATE_INTT_U_LOAD: begin
                    intt_start    <= 1'b1;
                    current_state <= STATE_INTT_U_WAIT;
                end
                STATE_INTT_U_WAIT: begin
                    if (intt_done) begin                        
                        if (poly_idx_reg == K_LAST[1:0]) begin 
                            current_state <= STATE_ADD_E1_REQ; 
                            poly_idx_reg  <= 2'd0;
                            coeff_counter <= 9'd0;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 2'd1;
                            current_state <= STATE_INTT_U_LOAD;
                        end
                    end
                end
                STATE_ADD_E1_REQ: current_state <= STATE_ADD_E1_WAIT; 
                STATE_ADD_E1_WAIT: current_state <= STATE_ADD_E1_COMPUTE;
                STATE_ADD_E1_COMPUTE: begin
                    if (coeff_counter == 9'd127) begin
                        if (poly_idx_reg == K_LAST[1:0]) begin
                            current_state <= STATE_MAC_V_LOAD; 
                            i_idx_reg     <= 8'd0;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 2'd1;
                            coeff_counter <= 9'd0;
                            current_state <= STATE_ADD_E1_REQ;
                        end
                    end else begin
                        coeff_counter <= coeff_counter + 9'd1;
                        current_state <= STATE_ADD_E1_REQ;
                    end
                end
                STATE_MAC_V_LOAD: begin
                    dot_start     <= 1'b1; 
                    current_state <= STATE_MAC_V_WAIT;
                end
                STATE_MAC_V_WAIT: begin
                    if (dot_done) begin
                        if (i_idx_reg == K_LAST) begin
                            current_state <= STATE_INTT_V_LOAD;
                        end else begin
                            i_idx_reg     <= i_idx_reg + 1'b1;
                            current_state <= STATE_MAC_V_LOAD;
                        end
                    end
                end
                STATE_INTT_V_LOAD: begin
                    intt_start    <= 1'b1;
                    current_state <= STATE_INTT_V_WAIT;
                end
                STATE_INTT_V_WAIT: begin
                    if (intt_done) begin                        
                        current_state <= STATE_ADD_E2_REQ; 
                        coeff_counter <= 9'd0;
                    end
                end
                STATE_ADD_E2_REQ: current_state <= STATE_ADD_E2_WAIT;
                STATE_ADD_E2_WAIT: current_state <= STATE_ADD_E2_COMPUTE;
                STATE_ADD_E2_COMPUTE: begin
                    if (coeff_counter == 9'd127) begin
                        current_state <= STATE_COMPRESS_U;
                        coeff_counter <= 10'd0;
                        wr_en_pipe <= 1'b0;
                    end else begin
                        coeff_counter <= coeff_counter + 9'd1;
                        current_state <= STATE_ADD_E2_REQ;
                    end
                end
                STATE_COMPRESS_U: begin
                    if (coeff_counter == (U_LEN + 10'd1)) begin
                        current_state <= STATE_COMPRESS_V;
                        coeff_counter <= 10'd0;
                        wr_en_pipe    <= 1'b0;
                    end else begin
                        coeff_counter <= coeff_counter + 10'd1;
                        wr_en_pipe    <= (coeff_counter < U_LEN); 
                        wr_addr_pipe  <= coeff_counter[9:0];      
                    end
                end
                STATE_COMPRESS_V: begin
                    if (coeff_counter == 10'd257) begin
                        current_state <= STATE_DONE;
                        coeff_counter <= 10'd0;
                        wr_en_pipe    <= 1'b0;
                    end else begin
                        coeff_counter <= coeff_counter + 10'd1;
                        wr_en_pipe    <= (coeff_counter < 10'd256);
                        wr_addr_pipe  <= coeff_counter[8:0];
                    end
                end
                STATE_DONE: begin
                    done  <= 1'b1;
                    ready <= 1'b1;
                end
                default: current_state <= STATE_IDLE;
            endcase
        end
    end
endmodule
