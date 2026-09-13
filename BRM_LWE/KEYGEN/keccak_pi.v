`timescale 1ns / 1ps
module keccak_pi (
    input  wire [1599:0] state_in_flat,
    output reg  [1599:0] pi_out_flat
);
    reg [63:0] state_in [0:4][0:4];
    reg [63:0] pi_out   [0:4][0:4];
    integer x, y;
    always @(*) begin
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                state_in[x][y] = state_in_flat[(5*y + x)*64 +: 64];
            end
        end
        for (x = 0; x < 5; x = x + 1) begin
            for (y = 0; y < 5; y = y + 1) begin
                pi_out[x][y] = state_in[(x + 3*y) % 5][x];
            end
        end
        for (y = 0; y < 5; y = y + 1) begin
            for (x = 0; x < 5; x = x + 1) begin
                pi_out_flat[(5*y + x)*64 +: 64] = pi_out[x][y];
            end
        end
    end
endmodule
