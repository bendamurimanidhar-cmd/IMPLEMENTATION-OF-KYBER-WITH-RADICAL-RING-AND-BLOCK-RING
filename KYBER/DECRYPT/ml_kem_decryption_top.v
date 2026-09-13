`timescale 1ns / 1ps
module mlkem_decrypt_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg          ready,
    output reg          done,
    output reg  [255:0] m_out, 
    output wire [9:0]  bram_u_addrA,
    output wire [9:0]  bram_u_addrB,
    output wire [11:0] bram_u_dinA,
    output wire [11:0] bram_u_dinB,
    output wire        bram_u_weA,
    output wire        bram_u_weB,
    input  wire [11:0] bram_u_doutA,
    input  wire [11:0] bram_u_doutB,
    output wire [7:0]  bram_v_addrA,
    output wire [7:0]  bram_v_addrB,
    output wire [11:0] bram_v_dinB,
    output wire        bram_v_weB,
    input  wire [11:0] bram_v_doutA,
    output wire [9:0]  bram_s_addrA,
    output wire [9:0]  bram_s_addrB,
    output wire [11:0] bram_s_dinA,
    output wire [11:0] bram_s_dinB,
    output wire        bram_s_weA,
    output wire        bram_s_weB,
    input  wire [11:0] bram_s_doutA,
    input  wire [11:0] bram_s_doutB,
    input  wire [7:0]  dbg_w_addr,
    output wire [11:0] dbg_w_data
);
    localparam Q = 12'd3329;
    localparam STATE_IDLE       = 4'd0;
    localparam STATE_PIPE_U     = 4'd1;
    localparam STATE_FLUSH_U    = 4'd2;
    localparam STATE_PIPE_V     = 4'd3;
    localparam STATE_FLUSH_V    = 4'd4;
    localparam STATE_NTT_U_START= 4'd5;
    localparam STATE_NTT_U_WAIT = 4'd6;
    localparam STATE_DOT_START  = 4'd7;
    localparam STATE_DOT_WAIT   = 4'd8;
    localparam STATE_INTT_START = 4'd9;
    localparam STATE_INTT_WAIT  = 4'd10;
    localparam STATE_SUB        = 4'd11;
    localparam STATE_SUB_FLUSH  = 4'd12;
    localparam STATE_DONE       = 4'd13;
    (* fsm_encoding = "gray" *) reg [3:0] current_state;
    reg [9:0] rd_idx;
    reg [1:0] poly_idx_reg;
    reg [9:0] u_wr_addr_p1;
    reg       u_we_p1;
    reg [7:0] v_wr_addr_p1;
    reg       v_we_p1;
    reg [7:0] sub_wr_addr_p1;
    reg       sub_we_p1;
    wire [9:0]  u_prime_addrA, u_prime_addrB;
    wire [11:0] u_prime_dinA,  u_prime_dinB;
    wire        u_prime_weA,   u_prime_weB;
    wire [11:0] u_prime_doutA, u_prime_doutB;
    wire [7:0]  v_prime_addrA, v_prime_addrB;
    wire [11:0] v_prime_dinA,  v_prime_dinB;
    wire        v_prime_weA,   v_prime_weB;
    wire [11:0] v_prime_doutA, v_prime_doutB;
    wire [7:0]  t_hat_addrA, t_hat_addrB;
    wire [11:0] t_hat_dinA,  t_hat_dinB;
    wire        t_hat_weA,   t_hat_weB;
    wire [11:0] t_hat_doutA, t_hat_doutB;
    tdp_bram_1024x12 mem_u_prime (
        .clk(clk),
        .addrA(u_prime_addrA), .dinA(u_prime_dinA), .weA(u_prime_weA), .doutA(u_prime_doutA),
        .addrB(u_prime_addrB), .dinB(u_prime_dinB), .weB(u_prime_weB), .doutB(u_prime_doutB)
    );
    tdp_bram_256x12 mem_v_prime (
        .clk(clk),
        .addrA(v_prime_addrA), .dinA(v_prime_dinA), .weA(v_prime_weA), .doutA(v_prime_doutA),
        .addrB(v_prime_addrB), .dinB(v_prime_dinB), .weB(v_prime_weB), .doutB(v_prime_doutB)
    );
    tdp_bram_256x12 mem_t_hat (
        .clk(clk),
        .addrA(t_hat_addrA), .dinA(t_hat_dinA), .weA(t_hat_weA), .doutA(t_hat_doutA),
        .addrB(t_hat_addrB), .dinB(t_hat_dinB), .weB(t_hat_weB), .doutB(t_hat_doutB)
    );
    wire        ntt_fwd_start, ntt_fwd_done;
    wire [7:0]  ntt_fwd_addrA, ntt_fwd_addrB;
    wire [11:0] ntt_fwd_dinA,  ntt_fwd_dinB;
    wire        ntt_fwd_weA,   ntt_fwd_weB;
    assign ntt_fwd_start = (current_state == STATE_NTT_U_START);
    ntt_forward ntt_fwd_inst (
        .clk(clk), .rst_n(rst_n), .start(ntt_fwd_start), .done(ntt_fwd_done),
        .bram_addrA(ntt_fwd_addrA), .bram_dinA(ntt_fwd_dinA), .bram_weA(ntt_fwd_weA), .bram_doutA(u_prime_doutA),
        .bram_addrB(ntt_fwd_addrB), .bram_dinB(ntt_fwd_dinB), .bram_weB(ntt_fwd_weB), .bram_doutB(u_prime_doutB)
    );
    wire        dot_start, dot_done;
    wire [7:0]  dot_addr_a0, dot_addr_a1, dot_addr_b0, dot_addr_b1;
    wire        dot_out_valid;
    wire [7:0]  dot_out_addr0, dot_out_addr1;
    wire [11:0] dot_out_c0, dot_out_c1;
    assign dot_start = (current_state == STATE_DOT_START);
    ntt_dot_prod dot_inst (
        .clk(clk), .rst_n(rst_n), .start(dot_start), .done(dot_done),
        .addr_a0(dot_addr_a0), .addr_a1(dot_addr_a1), .dout_a0(bram_s_doutA), .dout_a1(bram_s_doutB),
        .addr_b0(dot_addr_b0), .addr_b1(dot_addr_b1), .dout_b0(u_prime_doutA), .dout_b1(u_prime_doutB),
        .out_valid(dot_out_valid),
        .out_addr0(dot_out_addr0), .out_addr1(dot_out_addr1),
        .out_c0(dot_out_c0), .out_c1(dot_out_c1)
    );
    wire [12:0] t_acc_sum0 = t_hat_doutA + dot_out_c0;
    wire [11:0] t_acc_next0 = (t_acc_sum0 >= {1'b0, Q}) ? (t_acc_sum0 - {1'b0, Q}) : t_acc_sum0[11:0];
    wire [12:0] t_acc_sum1 = t_hat_doutB + dot_out_c1;
    wire [11:0] t_acc_next1 = (t_acc_sum1 >= {1'b0, Q}) ? (t_acc_sum1 - {1'b0, Q}) : t_acc_sum1[11:0];
    wire        intt_start, intt_done;
    wire [7:0]  intt_addrA, intt_addrB;
    wire [11:0] intt_dinA,  intt_dinB;
    wire        intt_weA,   intt_weB;
    assign intt_start = (current_state == STATE_INTT_START);
    ntt_inverse intt_inst (
        .clk(clk), .rst_n(rst_n), .start(intt_start), .done(intt_done),
        .bram_addrA(intt_addrA), .bram_dinA(intt_dinA), .bram_weA(intt_weA), .bram_doutA(t_hat_doutA),
        .bram_addrB(intt_addrB), .bram_dinB(intt_dinB), .bram_weB(intt_weB), .bram_doutB(t_hat_doutB)
    );
    wire [9:0]  u_in = bram_u_doutA[9:0];
    wire [21:0] u_mult = {u_in, 11'd0} + {1'b0, u_in, 10'd0} + {3'd0, u_in, 8'd0} + {11'd0, u_in};
    wire [21:0] decomp_u_raw = u_mult + 10'd512;
    wire [11:0] u_prime_val  = decomp_u_raw[21:10];
    reg [11:0] v_prime_val;
    always @(*) begin
        case (bram_v_doutA[3:0])
            4'd0:  v_prime_val = 12'd0;    4'd1:  v_prime_val = 12'd208;
            4'd2:  v_prime_val = 12'd416;  4'd3:  v_prime_val = 12'd624;
            4'd4:  v_prime_val = 12'd832;  4'd5:  v_prime_val = 12'd1040;
            4'd6:  v_prime_val = 12'd1248; 4'd7:  v_prime_val = 12'd1456;
            4'd8:  v_prime_val = 12'd1665; 4'd9:  v_prime_val = 12'd1873;
            4'd10: v_prime_val = 12'd2081; 4'd11: v_prime_val = 12'd2289;
            4'd12: v_prime_val = 12'd2497; 4'd13: v_prime_val = 12'd2705;
            4'd14: v_prime_val = 12'd2913; 4'd15: v_prime_val = 12'd3121;
            default: v_prime_val = 12'd0;
        endcase
    end
    wire [11:0] w_val = (v_prime_doutA < t_hat_doutA) ? (v_prime_doutA + Q - t_hat_doutA)
                                                        : (v_prime_doutA - t_hat_doutA);
    wire w_bit = (w_val >= 12'd833 && w_val <= 12'd2496) ? 1'b1 : 1'b0;
    assign bram_u_addrA = rd_idx;
    assign bram_u_addrB = 10'd0;
    assign bram_u_dinA  = 12'd0;
    assign bram_u_dinB  = 12'd0;
    assign bram_u_weA   = 1'b0;
    assign bram_u_weB   = 1'b0;
    assign bram_v_addrA = rd_idx[7:0];
    assign bram_v_addrB = 8'd0;
    assign bram_v_dinB  = 12'd0;
    assign bram_v_weB   = 1'b0;
    wire in_dot = (current_state == STATE_DOT_START) || (current_state == STATE_DOT_WAIT);
    assign bram_s_addrA = in_dot ? {poly_idx_reg, dot_addr_a0} : 10'd0;
    assign bram_s_addrB = in_dot ? {poly_idx_reg, dot_addr_a1} : 10'd0;
    assign bram_s_dinA  = 12'd0;
    assign bram_s_dinB  = 12'd0;
    assign bram_s_weA   = 1'b0;
    assign bram_s_weB   = 1'b0;
    wire in_pipe_u = (current_state == STATE_PIPE_U) || (current_state == STATE_FLUSH_U);
    wire in_ntt_u  = (current_state == STATE_NTT_U_START) || (current_state == STATE_NTT_U_WAIT);
    assign u_prime_addrA = in_pipe_u ? u_wr_addr_p1 :
                            in_ntt_u ? {poly_idx_reg, ntt_fwd_addrA} :
                            in_dot   ? {poly_idx_reg, dot_addr_b0} : 10'd0;
    assign u_prime_dinA  = in_pipe_u ? u_prime_val :
                            in_ntt_u ? ntt_fwd_dinA :
                                       12'd0;
    assign u_prime_weA   = in_pipe_u ? u_we_p1 :
                            in_ntt_u ? ntt_fwd_weA :
                                       1'b0;
    assign u_prime_addrB = in_ntt_u ? {poly_idx_reg, ntt_fwd_addrB} :
                            in_dot   ? {poly_idx_reg, dot_addr_b1} :
                                       10'd0;
    assign u_prime_dinB  = in_ntt_u ? ntt_fwd_dinB : 12'd0;
    assign u_prime_weB   = in_ntt_u ? ntt_fwd_weB : 1'b0;
    wire in_pipe_v = (current_state == STATE_PIPE_V) || (current_state == STATE_FLUSH_V);
    wire in_sub    = (current_state == STATE_SUB) || (current_state == STATE_SUB_FLUSH);
    assign v_prime_addrA = in_pipe_v ? v_wr_addr_p1 :
                            in_sub   ? rd_idx[7:0] :
                                       8'd0;
    assign v_prime_dinA  = in_pipe_v ? v_prime_val : 12'd0;
    assign v_prime_weA   = in_pipe_v ? v_we_p1 : 1'b0;
    assign v_prime_addrB = in_sub ? sub_wr_addr_p1 : dbg_w_addr;
    assign v_prime_dinB  = in_sub ? w_val : 12'd0;
    assign v_prime_weB   = in_sub ? sub_we_p1 : 1'b0;
    assign dbg_w_data    = v_prime_doutB;
    wire in_intt = (current_state == STATE_INTT_START) || (current_state == STATE_INTT_WAIT);
    assign t_hat_addrA = in_dot  ? ((poly_idx_reg != 2'd0) ? dot_addr_a0 : dot_out_addr0) :
                         in_intt ? intt_addrA :
                         in_sub  ? rd_idx[7:0] : 8'd0;
    assign t_hat_dinA  = in_dot  ? ((poly_idx_reg == 2'd0) ? dot_out_c0 : t_acc_next0) :
                         in_intt ? intt_dinA : 12'd0;
    assign t_hat_weA   = in_dot  ? dot_out_valid :
                         in_intt ? intt_weA : 1'b0;
    assign t_hat_addrB = in_dot  ? ((poly_idx_reg != 2'd0) ? dot_addr_a1 : dot_out_addr1) :
                         in_intt ? intt_addrB : 8'd0;
    assign t_hat_dinB  = in_dot  ? ((poly_idx_reg == 2'd0) ? dot_out_c1 : t_acc_next1) :
                         in_intt ? intt_dinB : 12'd0;
    assign t_hat_weB   = in_dot  ? dot_out_valid :
                         in_intt ? intt_weB : 1'b0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            ready         <= 1'b1;
            done          <= 1'b0;
            rd_idx        <= 9'd0;
            poly_idx_reg  <= 1'b0;
            u_we_p1        <= 1'b0; u_wr_addr_p1   <= 9'd0;
            v_we_p1        <= 1'b0; v_wr_addr_p1   <= 8'd0;
            sub_we_p1      <= 1'b0; sub_wr_addr_p1 <= 8'd0;
        end else begin
            u_we_p1        <= (current_state == STATE_PIPE_U);
            u_wr_addr_p1   <= rd_idx;
            v_we_p1        <= (current_state == STATE_PIPE_V);
            v_wr_addr_p1   <= rd_idx[7:0];
            sub_we_p1      <= (current_state == STATE_SUB);
            sub_wr_addr_p1 <= rd_idx[7:0];
            if (sub_we_p1) begin
                m_out[sub_wr_addr_p1] <= w_bit;
            end
            case (current_state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ready         <= 1'b0;
                        rd_idx        <= 10'd0; 
                        current_state <= STATE_PIPE_U;
                    end
                end
                STATE_PIPE_U: begin
                    if (rd_idx == 10'd767) begin 
                        rd_idx        <= 10'd0;
                        current_state <= STATE_FLUSH_U;
                    end else begin
                        rd_idx <= rd_idx + 10'd1;
                    end
                end
                STATE_FLUSH_U: begin
                    if (!u_we_p1) begin
                        current_state <= STATE_PIPE_V;
                    end
                end
                STATE_PIPE_V: begin
                    if (rd_idx == 10'd255) begin 
                        rd_idx        <= 10'd0;
                        current_state <= STATE_FLUSH_V;
                    end else begin
                        rd_idx <= rd_idx + 10'd1;
                    end
                end
                STATE_FLUSH_V: begin
                    if (!v_we_p1) begin
                        poly_idx_reg  <= 2'd0; 
                        current_state <= STATE_NTT_U_START;
                    end
                end
                STATE_NTT_U_START: begin
                    current_state <= STATE_NTT_U_WAIT;
                end
                STATE_NTT_U_WAIT: begin
                    if (ntt_fwd_done) begin
                        if (poly_idx_reg == 2'd2) begin
                            poly_idx_reg  <= 2'd0;
                            current_state <= STATE_DOT_START;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 2'd1;
                            current_state <= STATE_NTT_U_START;
                        end
                    end
                end
                STATE_DOT_START: begin
                    current_state <= STATE_DOT_WAIT;
                end
                STATE_DOT_WAIT: begin
                    if (dot_done) begin
                        if (poly_idx_reg == 2'd2) begin
                            poly_idx_reg  <= 2'd0;
                            current_state <= STATE_INTT_START;
                        end else begin
                            poly_idx_reg  <= poly_idx_reg + 2'd1;
                            current_state <= STATE_DOT_START;
                        end
                    end
                end
                STATE_INTT_START: begin
                    current_state <= STATE_INTT_WAIT;
                end
                STATE_INTT_WAIT: begin
                    if (intt_done) begin
                        rd_idx        <= 10'd0;
                        current_state <= STATE_SUB;
                    end
                end
                STATE_SUB: begin
                    if (rd_idx == 10'd255) begin 
                        rd_idx        <= 10'd0;
                        current_state <= STATE_SUB_FLUSH;
                    end else begin
                        rd_idx <= rd_idx + 10'd1;
                    end
                end
                STATE_SUB_FLUSH: begin
                    if (!sub_we_p1) begin
                        current_state <= STATE_DONE;
                    end
                end
                STATE_DONE: begin
                    done          <= 1'b1;
                    ready         <= 1'b1;
                    current_state <= STATE_IDLE;
                end
                default: current_state <= STATE_IDLE;
            endcase
        end
    end
endmodule
