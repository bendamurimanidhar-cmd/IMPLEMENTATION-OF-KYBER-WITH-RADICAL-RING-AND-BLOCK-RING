`timescale 1ns / 1ps
module cbd_eta2 (
    input  wire [3:0]  prf_bits,
    output reg  [11:0] out
);
    wire [1:0] a = prf_bits[1] + prf_bits[0];
    wire [1:0] b = prf_bits[3] + prf_bits[2];
    wire signed [2:0] sub_val = $signed({1'b0, a}) - $signed({1'b0, b});
    always @(*) begin
        case (sub_val)
            3'sb000: out = 12'd0; 
            3'sb001: out = 12'd0; 
            3'sb010: out = 12'd0; 
            3'sb111: out = 12'd0; 
            3'sb110: out = 12'd0; 
            default: out = 12'd0; 
        endcase
    end
endmodule
