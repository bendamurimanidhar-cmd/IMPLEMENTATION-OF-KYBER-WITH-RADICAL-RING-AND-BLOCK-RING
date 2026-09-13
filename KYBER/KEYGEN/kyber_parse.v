`timescale 1ns / 1ps
module kyber_parse (
    input  wire [23:0] bytes_in,      
    output wire [11:0] coeff1,        
    output wire [11:0] coeff2,        
    output wire        coeff1_valid,  
    output wire        coeff2_valid   
);
    wire [7:0] byte0 = bytes_in[7:0];
    wire [7:0] byte1 = bytes_in[15:8];
    wire [7:0] byte2 = bytes_in[23:16];
    assign coeff1 = {byte1[3:0], byte0};
    assign coeff2 = {byte2, byte1[7:4]};
    assign coeff1_valid = (coeff1 < 12'd3329);
    assign coeff2_valid = (coeff2 < 12'd3329);
endmodule
