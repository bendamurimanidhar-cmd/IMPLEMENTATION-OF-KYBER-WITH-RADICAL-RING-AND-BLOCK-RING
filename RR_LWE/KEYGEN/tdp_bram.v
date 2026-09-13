`timescale 1ns / 1ps
module tdp_bram #(
    parameter DEPTH  = 512, 
    parameter AWIDTH = 9,   
    parameter DWIDTH = 12   
)(
    input  wire              clk,   
    input  wire [AWIDTH-1:0] addrA, 
    input  wire [DWIDTH-1:0] dinA, 
    input  wire              weA,   
    output reg  [DWIDTH-1:0] doutA, 
    input  wire [AWIDTH-1:0] addrB,
    input  wire [DWIDTH-1:0] dinB,  
    input  wire              weB,   
    output reg  [DWIDTH-1:0] doutB  
);
    reg [DWIDTH-1:0] ram [0:DEPTH-1];
    integer i;
    initial begin
        for(i=0; i<DEPTH; i=i+1) ram[i] = 0;
    end
    always @(posedge clk) begin
        if (weA) begin
            ram[addrA] <= dinA; 
        end
        doutA <= ram[addrA];   
    end
    always @(posedge clk) begin
        if (weB) begin
            ram[addrB] <= dinB; 
        end
        doutB <= ram[addrB];   
    end
endmodule
