`timescale 1ns / 1ps
module cbd_eta2 (
    input  wire [3:0]  prf_bits,
    input  wire        is_secret,
    output reg  [11:0] coeff_out
);
    wire [1:0] a = prf_bits[1] + prf_bits[0];  
    wire [1:0] b = prf_bits[3] + prf_bits[2];
    wire signed [2:0] sub_val = $signed({1'b0, a}) - $signed({1'b0, b});
    always @(*) begin
        if (is_secret) begin
            case (sub_val)
                3'sb000: coeff_out = 12'd0; 
                3'sb001: coeff_out = 12'd0; 
                3'sb010: coeff_out = 12'd0; 
                3'sb111: coeff_out = 12'd0; 
                3'sb110: coeff_out = 12'd0; 
                default: coeff_out = 12'd0; 
            endcase
        end else begin
            case (sub_val)
                3'sb000: coeff_out = 12'd0; 
                3'sb001: coeff_out = 12'd0; 
                3'sb010: coeff_out = 12'd0; 
                3'sb111: coeff_out = 12'd0; 
                3'sb110: coeff_out = 12'd0; 
                default: coeff_out = 12'd0; 
            endcase
        end
    end
endmodule
