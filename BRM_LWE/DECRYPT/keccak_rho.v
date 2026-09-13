`timescale 1ns / 1ps
module keccak_rho (
    input  wire [1599:0] state_in_flat,
    output reg  [1599:0] rho_out_flat
);
    reg [63:0] state_in [0:4][0:4];
    reg [63:0] rho_out  [0:4][0:4];
    integer x, y;
    always @(*) begin
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                state_in[x][y] = state_in_flat[(5*y + x)*64 +: 64];
            end
        end
        rho_out[0][0] = state_in[0][0];                                        
        rho_out[1][0] = {state_in[1][0][62:0], state_in[1][0][63]};            
        rho_out[2][0] = {state_in[2][0][ 1:0], state_in[2][0][63: 2]};         
        rho_out[3][0] = {state_in[3][0][35:0], state_in[3][0][63:36]};         
        rho_out[4][0] = {state_in[4][0][36:0], state_in[4][0][63:37]};         
        rho_out[0][1] = {state_in[0][1][27:0], state_in[0][1][63:28]};         
        rho_out[1][1] = {state_in[1][1][19:0], state_in[1][1][63:20]};         
        rho_out[2][1] = {state_in[2][1][57:0], state_in[2][1][63:58]};         
        rho_out[3][1] = {state_in[3][1][ 8:0], state_in[3][1][63: 9]};         
        rho_out[4][1] = {state_in[4][1][43:0], state_in[4][1][63:44]};         
        rho_out[0][2] = {state_in[0][2][60:0], state_in[0][2][63:61]};         
        rho_out[1][2] = {state_in[1][2][53:0], state_in[1][2][63:54]};         
        rho_out[2][2] = {state_in[2][2][20:0], state_in[2][2][63:21]};         
        rho_out[3][2] = {state_in[3][2][38:0], state_in[3][2][63:39]};         
        rho_out[4][2] = {state_in[4][2][24:0], state_in[4][2][63:25]};         
        rho_out[0][3] = {state_in[0][3][22:0], state_in[0][3][63:23]};         
        rho_out[1][3] = {state_in[1][3][18:0], state_in[1][3][63:19]};         
        rho_out[2][3] = {state_in[2][3][48:0], state_in[2][3][63:49]};         
        rho_out[3][3] = {state_in[3][3][42:0], state_in[3][3][63:43]};         
        rho_out[4][3] = {state_in[4][3][55:0], state_in[4][3][63:56]};         
        rho_out[0][4] = {state_in[0][4][45:0], state_in[0][4][63:46]};         
        rho_out[1][4] = {state_in[1][4][61:0], state_in[1][4][63:62]};         
        rho_out[2][4] = {state_in[2][4][ 2:0], state_in[2][4][63: 3]};         
        rho_out[3][4] = {state_in[3][4][ 7:0], state_in[3][4][63: 8]};         
        rho_out[4][4] = {state_in[4][4][49:0], state_in[4][4][63:50]};         
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                rho_out_flat[(5*y + x)*64 +: 64] = rho_out[x][y];
            end
        end
    end
endmodule
