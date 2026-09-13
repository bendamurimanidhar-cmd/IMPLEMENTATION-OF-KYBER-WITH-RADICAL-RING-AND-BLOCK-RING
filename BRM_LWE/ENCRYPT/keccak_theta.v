`timescale 1ns / 1ps
module keccak_theta (
    input  wire [1599:0] state_in_flat,
    output reg  [1599:0] theta_out_flat
);
    reg [63:0] state_in  [0:4][0:4];
    reg [63:0] theta_out [0:4][0:4];
    reg [63:0] C [0:4];
    reg [63:0] D [0:4];
    integer x, y;
    always @(*) begin
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                state_in[x][y] = state_in_flat[(5*y + x)*64 +: 64];
            end
        end
        for (x = 0; x < 5; x = x + 1) begin
            C[x] = state_in[x][0] ^ state_in[x][1] ^ state_in[x][2] ^ state_in[x][3] ^ state_in[x][4];
        end
        D[0] = C[4] ^ {C[1][62:0], C[1][63]}; 
        D[1] = C[0] ^ {C[2][62:0], C[2][63]}; 
        D[2] = C[1] ^ {C[3][62:0], C[3][63]}; 
        D[3] = C[2] ^ {C[4][62:0], C[4][63]}; 
        D[4] = C[3] ^ {C[0][62:0], C[0][63]}; 
        for (x = 0; x < 5; x = x + 1) begin
            for (y = 0; y < 5; y = y + 1) begin
                theta_out[x][y] = state_in[x][y] ^ D[x];
            end
        end
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                theta_out_flat[(5*y + x)*64 +: 64] = theta_out[x][y];
            end
        end
    end
endmodule
