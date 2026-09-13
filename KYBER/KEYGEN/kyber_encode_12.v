`timescale 1ns / 1ps
module kyber_encode_12 (
    input  wire [11:0] coeff0, 
    input  wire [11:0] coeff1, 
    output wire [7:0]  byte0,  
    output wire [7:0]  byte1,  
    output wire [7:0]  byte2   
);
    assign byte0 = coeff0[7:0];
    assign byte1 = {coeff1[3:0], coeff0[11:8]};
    assign byte2 = coeff1[11:4];
endmodule
