`timescale 1ns / 1ps
module tdp_bram_2304x12 (
    input  wire        clk,
    input  wire [11:0] addrA,
    input  wire [11:0] dinA,
    input  wire        weA,
    output reg  [11:0] doutA,
    input  wire [11:0] addrB,
    input  wire [11:0] dinB,
    input  wire        weB,
    output reg  [11:0] doutB
);
    (* ram_style = "block" *) reg [11:0] ram [0:2303];
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
