`timescale 1ns / 1ps
module mlkem_keygen_top #(
    parameter K = 3   
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start,
    output reg            ready,
    output reg            done,
    output reg            ek_we,
    output reg  [11:0]    ek_addr,   
    output reg  [23:0]    ek_dout,
    output reg            dk_we,
    output reg  [11:0]    dk_addr,   
    output reg  [23:0]    dk_dout
);
    wire [255:0] seed_d = 256'h2CB843A02EF02EE109305F39119FABF49AB90A57FFECB3A0E75E179450F52761;
    wire [255:0] seed_z = 256'h84CC9121AE56FBF39E67ADBD83AD2D3E3BB80843645206BDD9F2F629E3CC49B7;
    localparam [7:0] K_PARAM = K[7:0];
    localparam N          = 256;                
    localparam VEC_DEPTH   = K * N;              
    localparam VEC_AW      = $clog2(VEC_DEPTH);  
    localparam MAT_DEPTH   = K * K * N;          
    localparam MAT_AW      = $clog2(MAT_DEPTH);  
    localparam ENC_WORDS   = (K * N) / 2;        
    localparam RHO_WORDS   = 11;                 
    localparam STATE_IDLE      = 4'd0;
    localparam STATE_HASH_SEED = 4'd1;
    localparam STATE_GEN_VECTORS = 4'd2;
    localparam STATE_SAVE_VECTORS = 4'd3;
    localparam STATE_GEN_MATRIX = 4'd4;
    localparam STATE_PROCESS_REJ = 4'd5;
    localparam STATE_SQUEEZE_MATRIX = 4'd6;
    localparam STATE_NTT_S_LOAD = 4'd7;
    localparam STATE_NTT_S_WAIT = 4'd8;
    localparam STATE_NTT_E_LOAD = 4'd9;
    localparam STATE_NTT_E_WAIT = 4'd10;
    localparam STATE_MAC_LOAD = 4'd11;
    localparam STATE_MAC_WAIT = 4'd12;
    localparam STATE_ENCODE_REQ  = 4'd13;
    localparam STATE_ENCODE_WAIT = 4'd14;
    localparam STATE_APPEND_RHO  = 4'd15;
    reg [255:0] rho;
    reg [255:0] sigma;
    (* fsm_encoding = "gray" *) reg [3:0] current_state;
    reg  cmd_hash_seed;  
    reg  cmd_gen_vector;  
    reg  cmd_gen_matrix;  
    reg  cmd_squeeze_more;  
    reg [7:0] nonce_reg; 
    reg [7:0] i_idx_reg; 
    reg [7:0] j_idx_reg;
    reg  [8:0] coeff_counter;   
    reg [7:0] bitstream_count;   
    reg [7:0]  poly_idx_reg;          
    reg [8:0]  idx;			
    reg           ntt_start;
    reg           dot_start;
    reg [VEC_AW-1:0] encode_idx;      
    wire          keccak_ready;
    wire          keccak_valid;
    wire [511:0]  sha3_out;	
    wire [1343:0] shake_out;
    wire [3:0] cbd_in_bits;
    wire       cbd_is_secret;
    wire [11:0] cbd_coeff_out;
    wire [7:0] poly_sel = cbd_is_secret ? nonce_reg : (nonce_reg - K_PARAM);
    wire [VEC_AW-1:0] vector_flat_addr = poly_sel * N + coeff_counter[8:0];
    wire [23:0] current_3_bytes = shake_out[ (bitstream_count * 8) +: 24 ];
    wire [11:0] d1, d2;
    wire        d1_valid, d2_valid;
    wire [MAT_AW-1:0] base_idx = (i_idx_reg * K_PARAM + j_idx_reg) * N;
    wire hit_256 = (coeff_counter >= 9'd256) || (coeff_counter == 9'd255 && d1_valid) ||
                   (coeff_counter == 9'd254 && d1_valid && d2_valid) || (coeff_counter == 9'd255 && !d1_valid && d2_valid);
    wire          ntt_done;
    wire          dot_done;
    wire [7:0] ek_b0, ek_b1, ek_b2;
    wire [11:0] final_c0;
    wire [11:0] final_c1;
    wire we_s;
    wire we_e;
    wire is_last_j = (j_idx_reg == (K_PARAM - 8'd1));
    wire [7:0] dk_b0, dk_b1, dk_b2;
    wire [VEC_AW-1:0]  bram_s_addrA, bram_s_addrB;
    wire [11:0] bram_s_dinA,  bram_s_dinB;
    wire        bram_s_weA,   bram_s_weB;
    wire [11:0] bram_s_doutA, bram_s_doutB;
    wire [VEC_AW-1:0]  bram_e_addrA, bram_e_addrB;
    wire [11:0] bram_e_dinA,  bram_e_dinB;
    wire        bram_e_weA,   bram_e_weB;
    wire [11:0] bram_e_doutA, bram_e_doutB;
    wire [MAT_AW-1:0]  bram_A_addrA, bram_A_addrB;
    wire [11:0] bram_A_dinA,  bram_A_dinB;
    wire        bram_A_weA,   bram_A_weB;
    wire [11:0] bram_A_doutA, bram_A_doutB;
    wire [VEC_AW-1:0]  bram_t_vec_addrA, bram_t_vec_addrB;
    wire [11:0] bram_t_vec_dinA,  bram_t_vec_dinB;
    wire        bram_t_vec_weA,   bram_t_vec_weB;
    wire [11:0] bram_t_vec_doutA, bram_t_vec_doutB;
    wire [7:0]  ntt_bram_addrA, ntt_bram_addrB;
    wire [11:0] ntt_bram_dinA,  ntt_bram_dinB;
    wire        ntt_bram_weA,   ntt_bram_weB;
    wire        dot_out_valid;
    wire [7:0]  dot_out_addr0, dot_out_addr1;
    wire [11:0] dot_out_c0,    dot_out_c1;
    wire [7:0]  dot_addr_a0, dot_addr_a1;
    wire [7:0]  dot_addr_b0, dot_addr_b1;
    wire [11:0] dot_dout_a0, dot_dout_a1;
    wire [VEC_AW-1:0]  ntt_full_addrA = poly_idx_reg * N + ntt_bram_addrA;
    wire [VEC_AW-1:0]  ntt_full_addrB = poly_idx_reg * N + ntt_bram_addrB;
    assign bram_s_addrA = (current_state == STATE_NTT_S_WAIT) ? ntt_full_addrA :
                          (current_state == STATE_MAC_WAIT)   ? (j_idx_reg * N + dot_addr_b0) :
                          (current_state == STATE_ENCODE_REQ) ? (encode_idx * 2) : vector_flat_addr;
    assign bram_s_dinA  = (current_state == STATE_NTT_S_WAIT) ? ntt_bram_dinA  : cbd_coeff_out;
    assign bram_s_weA   = (current_state == STATE_NTT_S_WAIT) ? ntt_bram_weA   : we_s;
    assign bram_s_addrB = (current_state == STATE_NTT_S_WAIT) ? ntt_full_addrB :
                          (current_state == STATE_MAC_WAIT)   ? (j_idx_reg * N + dot_addr_b1) :
                          (current_state == STATE_ENCODE_REQ) ? (encode_idx * 2 + 1) : {VEC_AW{1'b0}};
    assign bram_s_dinB  = ntt_bram_dinB;
    assign bram_s_weB   = (current_state == STATE_NTT_S_WAIT) ? ntt_bram_weB : 1'b0;
    assign bram_e_addrA = (current_state == STATE_NTT_E_WAIT) ? ntt_full_addrA :
                          (current_state == STATE_MAC_WAIT)   ? (i_idx_reg * N + dot_addr_b0) : vector_flat_addr;
    assign bram_e_dinA  = (current_state == STATE_NTT_E_WAIT) ? ntt_bram_dinA  : cbd_coeff_out;
    assign bram_e_weA   = (current_state == STATE_NTT_E_WAIT) ? ntt_bram_weA   : we_e;
    assign bram_e_addrB = (current_state == STATE_NTT_E_WAIT) ? ntt_full_addrB :
                          (current_state == STATE_MAC_WAIT)   ? (i_idx_reg * N + dot_addr_b1) : {VEC_AW{1'b0}};
    assign bram_e_dinB  = ntt_bram_dinB;
    assign bram_e_weB   = (current_state == STATE_NTT_E_WAIT) ? ntt_bram_weB : 1'b0;
    assign bram_A_addrA = (current_state == STATE_PROCESS_REJ) ? (base_idx + coeff_counter) : (base_idx + dot_addr_a0);
    assign bram_A_dinA = d1_valid ? d1 : d2;
    assign bram_A_weA = (current_state == STATE_PROCESS_REJ) && (d1_valid || d2_valid) && (coeff_counter < 9'd256);
    assign bram_A_addrB = (current_state == STATE_PROCESS_REJ) ? (base_idx + coeff_counter + 10'd1) : (base_idx + dot_addr_a1);
    assign bram_A_dinB = d2;
    assign bram_A_weB = (current_state == STATE_PROCESS_REJ) && d1_valid && d2_valid && (coeff_counter < 9'd255);
    assign bram_t_vec_addrA = (current_state == STATE_ENCODE_REQ || current_state == STATE_ENCODE_WAIT) ? (encode_idx * 2)     : (i_idx_reg * N + dot_out_addr0);
    assign bram_t_vec_dinA  = final_c0;
    assign bram_t_vec_weA   = dot_out_valid && is_last_j;
    always @(posedge clk) if (bram_t_vec_weA) $display("[DEBUG] WRITING T_VEC addr=%0d, din=%0x", bram_t_vec_addrA, bram_t_vec_dinA);
    assign bram_t_vec_addrB = (current_state == STATE_ENCODE_REQ || current_state == STATE_ENCODE_WAIT) ? (encode_idx * 2 + 1) : (i_idx_reg * N + dot_out_addr1);
    assign bram_t_vec_dinB  = final_c1;
    assign bram_t_vec_weB   = dot_out_valid && is_last_j;
    assign dot_dout_a0 = bram_A_doutA;
    assign dot_dout_a1 = bram_A_doutB;
    wire is_first_j = (j_idx_reg == 8'd0);
    wire write_to_1  = ~j_idx_reg[0];   
    wire read_from_1  =  j_idx_reg[0];  
    wire [7:0]  acc0_addrA, acc0_addrB;
    wire [11:0] acc0_dinA,  acc0_dinB;
    wire        acc0_weA,   acc0_weB;
    wire [11:0] acc0_doutA, acc0_doutB;
    wire [7:0]  acc1_addrA, acc1_addrB;
    wire [11:0] acc1_dinA,  acc1_dinB;
    wire        acc1_weA,   acc1_weB;
    wire [11:0] acc1_doutA, acc1_doutB;
    wire [11:0] acc_prev0 = read_from_1 ? acc1_doutA : acc0_doutA;
    wire [11:0] acc_prev1 = read_from_1 ? acc1_doutB : acc0_doutB;
    wire [13:0] mid_raw0   = acc_prev0 + dot_out_c0;
    wire [11:0] mid_final0 = (mid_raw0 < 14'd3329) ? mid_raw0[11:0] : (mid_raw0 - 14'd3329);
    wire [13:0] mid_raw1   = acc_prev1 + dot_out_c1;
    wire [11:0] mid_final1 = (mid_raw1 < 14'd3329) ? mid_raw1[11:0] : (mid_raw1 - 14'd3329);
    wire [11:0] acc_din0 = is_first_j ? dot_out_c0 : mid_final0;
    wire [11:0] acc_din1 = is_first_j ? dot_out_c1 : mid_final1;
    assign acc0_addrA = write_to_1 ? dot_addr_a0 : dot_out_addr0;
    assign acc0_addrB = write_to_1 ? dot_addr_a1 : dot_out_addr1;
    assign acc0_dinA  = acc_din0;
    assign acc0_dinB  = acc_din1;
    assign acc0_weA   = dot_out_valid && !write_to_1 && !is_last_j;
    assign acc0_weB   = dot_out_valid && !write_to_1 && !is_last_j;
    assign acc1_addrA = write_to_1 ? dot_out_addr0 : dot_addr_a0;
    assign acc1_addrB = write_to_1 ? dot_out_addr1 : dot_addr_a1;
    assign acc1_dinA  = acc_din0;
    assign acc1_dinB  = acc_din1;
    assign acc1_weA   = dot_out_valid && write_to_1 && !is_last_j;
    assign acc1_weB   = dot_out_valid && write_to_1 && !is_last_j;
    wire [13:0] raw_sum0 = acc_prev0 + dot_out_c0 + bram_e_doutA;
    wire [13:0] raw_sum1 = acc_prev1 + dot_out_c1 + bram_e_doutB;
    wire [13:0] sub1_0   = raw_sum0 - 14'd3329;
    wire [13:0] sub2_0   = sub1_0 - 14'd3329;
    assign final_c0 = (raw_sum0 < 14'd3329) ? raw_sum0[11:0] : (sub1_0 < 14'd3329) ? sub1_0[11:0] : sub2_0[11:0];
    wire [13:0] sub1_1   = raw_sum1 - 14'd3329;
    wire [13:0] sub2_1   = sub1_1 - 14'd3329;
    assign final_c1 = (raw_sum1 < 14'd3329) ? raw_sum1[11:0] :
                           (sub1_1 < 14'd3329)   ? sub1_1[11:0]   : sub2_1[11:0];
    kyber_keccak_wrapper u_keccak (.clk(clk), .rst_n(rst_n),
        .cmd_hash_seed    (cmd_hash_seed),
        .cmd_gen_vector   (cmd_gen_vector),
        .cmd_gen_matrix   (cmd_gen_matrix),
        .cmd_squeeze_more (cmd_squeeze_more),
        .seed_in          (seed_d),
        .k_param          (K_PARAM),
        .sigma            (sigma),
        .nonce            (nonce_reg),
        .rho              (rho),
        .i_idx            (i_idx_reg),
        .j_idx            (j_idx_reg),
        .ready            (keccak_ready),
        .dout_valid       (keccak_valid),
        .sha3_out         (sha3_out),
        .shake_out        (shake_out)
    );
    cbd_eta2 u_cbd (
        .prf_bits   (cbd_in_bits),
        .is_secret  (cbd_is_secret),
        .coeff_out  (cbd_coeff_out)
    );
    kyber_parse u_parser (
        .bytes_in      (current_3_bytes),
        .coeff1        (d1),
        .coeff2        (d2),
        .coeff1_valid  (d1_valid),
        .coeff2_valid  (d2_valid)
    );
    ntt_dot_prod #(.Q(3329)) u_dot (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (dot_start),
        .done       (dot_done),
        .addr_a0    (dot_addr_a0),
        .addr_a1    (dot_addr_a1),
        .dout_a0    (dot_dout_a0),
        .dout_a1    (dot_dout_a1),
        .addr_b0    (dot_addr_b0),
        .addr_b1    (dot_addr_b1),
        .dout_b0    (bram_s_doutA),
        .dout_b1    (bram_s_doutB),
        .out_valid  (dot_out_valid),
        .out_addr0  (dot_out_addr0),
        .out_addr1  (dot_out_addr1),
        .out_c0     (dot_out_c0),
        .out_c1     (dot_out_c1)
    );
    kyber_encode_12 u_encode_ek (
        .coeff0 (bram_t_vec_doutA),
        .coeff1 (bram_t_vec_doutB),
        .byte0  (ek_b0),
        .byte1  (ek_b1),
        .byte2  (ek_b2)
    );
    wire [11:0] dk_norm_0;
    wire [11:0] dk_norm_1;
    mont_mult mm_dk0 (
        .a(bram_s_doutA),
        .b(12'd1), 
        .c(dk_norm_0) 
    );
    mont_mult mm_dk1 (
        .a(bram_s_doutB),
        .b(12'd1), 
        .c(dk_norm_1)
    );
    kyber_encode_12 u_encode_dk (
        .coeff0 (dk_norm_0),  
        .coeff1 (dk_norm_1), 
        .byte0  (dk_b0),
        .byte1  (dk_b1),
        .byte2  (dk_b2)
    );
    ntt_forward #(.Q(3329)) u_ntt_shared (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (ntt_start),
        .done       (ntt_done),
        .bram_addrA (ntt_bram_addrA),
        .bram_dinA  (ntt_bram_dinA),
        .bram_weA   (ntt_bram_weA),
        .bram_doutA ((current_state == STATE_NTT_S_WAIT) ? bram_s_doutA : bram_e_doutA),
        .bram_addrB (ntt_bram_addrB),
        .bram_dinB  (ntt_bram_dinB),
        .bram_weB   (ntt_bram_weB),
        .bram_doutB ((current_state == STATE_NTT_S_WAIT) ? bram_s_doutB : bram_e_doutB)
    );
   tdp_bram #(.DEPTH(VEC_DEPTH), .AWIDTH(VEC_AW)) mem_e (
        .clk(clk),
        .addrA(bram_e_addrA), .dinA(bram_e_dinA), .weA(bram_e_weA), .doutA(bram_e_doutA),
        .addrB(bram_e_addrB), .dinB(bram_e_dinB), .weB(bram_e_weB), .doutB(bram_e_doutB)
    );
    tdp_bram #(.DEPTH(VEC_DEPTH), .AWIDTH(VEC_AW)) mem_s (
        .clk(clk),
        .addrA(bram_s_addrA), .dinA(bram_s_dinA), .weA(bram_s_weA), .doutA(bram_s_doutA),
        .addrB(bram_s_addrB), .dinB(bram_s_dinB), .weB(bram_s_weB), .doutB(bram_s_doutB)
    );
    tdp_bram #(.DEPTH(MAT_DEPTH), .AWIDTH(MAT_AW)) mem_A (
        .clk(clk),
        .addrA(bram_A_addrA), .dinA(bram_A_dinA), .weA(bram_A_weA), .doutA(bram_A_doutA),
        .addrB(bram_A_addrB), .dinB(bram_A_dinB), .weB(bram_A_weB), .doutB(bram_A_doutB)
    );
    tdp_bram #(.DEPTH(N), .AWIDTH(8)) mem_t_acc0 (
        .clk(clk),
        .addrA(acc0_addrA), .dinA(acc0_dinA), .weA(acc0_weA), .doutA(acc0_doutA),
        .addrB(acc0_addrB), .dinB(acc0_dinB), .weB(acc0_weB), .doutB(acc0_doutB)
    );
    tdp_bram #(.DEPTH(N), .AWIDTH(8)) mem_t_acc1 (
        .clk(clk),
        .addrA(acc1_addrA), .dinA(acc1_dinA), .weA(acc1_weA), .doutA(acc1_doutA),
        .addrB(acc1_addrB), .dinB(acc1_dinB), .weB(acc1_weB), .doutB(acc1_doutB)
    );
    tdp_bram #(.DEPTH(VEC_DEPTH), .AWIDTH(VEC_AW)) mem_t_vec (
        .clk(clk),
        .addrA(bram_t_vec_addrA), .dinA(bram_t_vec_dinA), .weA(bram_t_vec_weA), .doutA(bram_t_vec_doutA),
        .addrB(bram_t_vec_addrB), .dinB(bram_t_vec_dinB), .weB(bram_t_vec_weB), .doutB(bram_t_vec_doutB)
    );
    assign we_s = (current_state == STATE_SAVE_VECTORS) && cbd_is_secret;
    assign we_e = (current_state == STATE_SAVE_VECTORS) && !cbd_is_secret;
    assign cbd_in_bits = shake_out[ (coeff_counter * 4) +: 4 ];
    assign cbd_is_secret = (nonce_reg < K_PARAM) ? 1'b1 : 1'b0;
    always @(posedge clk) if (dot_out_valid) $display("[DEBUG] dot_out_valid=1, is_last_j=%0d", is_last_j);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state    <= STATE_IDLE;
            ready            <= 1'b1;
            done             <= 1'b0;
            rho              <= 256'd0;
            sigma            <= 256'd0;
            nonce_reg        <= 8'd0;
            i_idx_reg        <= 8'd0;
            j_idx_reg        <= 8'd0;
            cmd_hash_seed    <= 1'b0;
            cmd_gen_vector   <= 1'b0;
            cmd_gen_matrix   <= 1'b0;
            cmd_squeeze_more <= 1'b0;
            coeff_counter    <= 9'd0;
            bitstream_count  <= 8'd0;
            poly_idx_reg     <= 8'd0;
            idx              <= 9'd0;
            ntt_start        <= 1'b0;
            dot_start        <= 1'b0;
            encode_idx       <= {VEC_AW{1'b0}};
            ek_we            <= 1'b0;
            dk_we            <= 1'b0;
            ek_addr          <= 12'd0;
            dk_addr          <= 12'd0;
        end else begin
            cmd_hash_seed    <= 1'b0;
            cmd_gen_vector   <= 1'b0;
            cmd_gen_matrix   <= 1'b0;
            cmd_squeeze_more <= 1'b0;
            ek_we            <= 1'b0; 
            dk_we            <= 1'b0;
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start && keccak_ready) begin
                        ready         <= 1'b0;
                        current_state <= STATE_HASH_SEED;
                        cmd_hash_seed <= 1'b1; 
                    end
                end
                STATE_HASH_SEED: begin
                    if (keccak_valid) begin
                        rho           <= sha3_out[511:256]; 
                        sigma         <= sha3_out[255:0];   
                        nonce_reg     <= 8'd0;
                        coeff_counter <= 8'd0;
                        current_state <= STATE_GEN_VECTORS;
                        cmd_gen_vector<= 1'b1;    
                    end
                end
                STATE_GEN_VECTORS: begin
                    if (keccak_valid) begin
                        coeff_counter <= 8'd0;
                        current_state <= STATE_SAVE_VECTORS;
                    end
                end
                STATE_SAVE_VECTORS: begin
                    if (coeff_counter == 8'd255) begin
                        if (nonce_reg == (2*K_PARAM - 8'd1)) begin
                            i_idx_reg      <= 8'd0;
                            j_idx_reg      <= 8'd0;
                            current_state  <= STATE_GEN_MATRIX;
                            cmd_gen_matrix <= 1'b1;
                        end else begin
                            nonce_reg      <= nonce_reg + 1'b1;
                            current_state  <= STATE_GEN_VECTORS;
                            cmd_gen_vector <= 1'b1; 
                        end
                    end else begin
                        coeff_counter <= coeff_counter + 1'b1;
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
                        if (coeff_counter < 9'd255) begin
                            coeff_counter <= coeff_counter + 9'd2;
                        end else if (coeff_counter == 9'd255) begin
                            coeff_counter <= 9'd256;
                        end
                    end 
                    else if (d1_valid) begin
                        if (coeff_counter < 9'd256) begin
                            coeff_counter <= coeff_counter + 9'd1;
                        end
                    end 
                    else if (d2_valid) begin
                        if (coeff_counter < 9'd256) begin
                            coeff_counter <= coeff_counter + 9'd1;
                        end
                    end
                    if (hit_256) begin
                        if (j_idx_reg == (K_PARAM - 8'd1)) begin
                            j_idx_reg <= 8'd0;
                            if (i_idx_reg == (K_PARAM - 8'd1)) begin
                                current_state <= STATE_NTT_S_LOAD; 
                                poly_idx_reg  <= 8'd0;
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
                    else begin
                        bitstream_count <= bitstream_count + 8'd3;
                    end
                end
                STATE_SQUEEZE_MATRIX: begin
                    if (keccak_valid) begin
                        bitstream_count <= 8'd0;
                        current_state   <= STATE_PROCESS_REJ;
                    end
                end
                STATE_NTT_S_LOAD: begin
                    ntt_start     <= 1'b1;
                    current_state <= STATE_NTT_S_WAIT;
                end
                STATE_NTT_S_WAIT: begin
                    ntt_start <= 1'b0;
                    if (ntt_done) begin        
                        if (poly_idx_reg == (K_PARAM - 8'd1)) begin
                            current_state <= STATE_NTT_E_LOAD; 
                            poly_idx_reg  <= 8'd0;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 8'd1;
                            current_state <= STATE_NTT_S_LOAD;
                        end
                    end
                end
                STATE_NTT_E_LOAD: begin
                    ntt_start     <= 1'b1;
                    current_state <= STATE_NTT_E_WAIT;
                end
                STATE_NTT_E_WAIT: begin
                    ntt_start <= 1'b0; 
                    if (ntt_done) begin   
                        if (poly_idx_reg == (K_PARAM - 8'd1)) begin
                            current_state <= STATE_MAC_LOAD;
                            i_idx_reg     <= 8'd0;
                            j_idx_reg     <= 8'd0;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 8'd1;
                            current_state <= STATE_NTT_E_LOAD;
                        end
                    end
                end
                STATE_MAC_LOAD: begin
                    dot_start     <= 1'b1;  
                    current_state <= STATE_MAC_WAIT;
                end
                STATE_MAC_WAIT: begin
                    dot_start <= 1'b0;
                    if (dot_done) begin
                        if (j_idx_reg == (K_PARAM - 8'd1)) begin
                            if (i_idx_reg == (K_PARAM - 8'd1)) begin
                                current_state <= STATE_ENCODE_REQ;
                                encode_idx    <= {VEC_AW{1'b0}};
                            end else begin
                                i_idx_reg     <= i_idx_reg + 1'b1;
                                j_idx_reg     <= 8'd0;
                                current_state <= STATE_MAC_LOAD;
                            end
                        end else begin
                            j_idx_reg     <= j_idx_reg + 1'b1;
                            current_state <= STATE_MAC_LOAD;
                        end
                    end
                end
                STATE_ENCODE_REQ: begin
                    current_state <= STATE_ENCODE_WAIT;
                end
                STATE_ENCODE_WAIT: begin
                    if (encode_idx == 0 || encode_idx == 1) $display("[DEBUG] ENCODE_WAIT idx=%0d, we=1", encode_idx);
                    ek_we   <= 1'b1;
                    ek_addr <= encode_idx;
                    ek_dout <= {ek_b2, ek_b1, ek_b0}; 
                    dk_we   <= 1'b1;
                    dk_addr <= encode_idx;
                    dk_dout <= {dk_b2, dk_b1, dk_b0};
                    if (encode_idx == (ENC_WORDS - 1)) begin
                        current_state <= STATE_APPEND_RHO;
                        idx           <= 9'd0; 
                    end else begin
                        encode_idx    <= encode_idx + 1'b1;
                        current_state <= STATE_ENCODE_REQ;
                    end
                end
                STATE_APPEND_RHO: begin
                    dk_we   <= 1'b0;
                    ek_we   <= 1'b0;   
                    if (idx < 9'd10) begin
                        ek_we   <= 1'b1;
                        ek_addr <= ENC_WORDS[11:0] + idx;       
                        ek_dout <= {rho[255-(idx*24)-16 -: 8],rho[255-(idx*24)-8 -: 8],rho[255-(idx*24) -: 8]};
                        idx <= idx + 9'd1;
                    end
                    else if (idx == 9'd10) begin
                        ek_we   <= 1'b1;
                        ek_addr <= ENC_WORDS[11:0] + idx;       
                        ek_dout <= {8'b0, rho[7:0], rho[15:8]};
                        idx <= idx + 9'd1;
                    end
                    else begin
                        current_state <= STATE_IDLE;
                        done          <= 1'b1;
                        ready         <= 1'b1;
                        idx           <= 9'd0;
                    end
                end
                default: current_state <= STATE_IDLE;
            endcase
        end
    end
endmodule
