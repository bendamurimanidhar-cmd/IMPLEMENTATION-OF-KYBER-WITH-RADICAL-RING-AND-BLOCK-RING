`timescale 1ns / 1ps
module endian_swap #(
    parameter DATA_BITS = 272         
) (
    input  wire [DATA_BITS-1:0] in_data,
    output wire [DATA_BITS-1:0] out_data
);
    localparam NUM_BYTES = DATA_BITS / 8;
    genvar i; 
    generate
        for (i = 0; i < NUM_BYTES; i = i + 1) begin : swap_loop
            assign out_data[(NUM_BYTES - 1 - i)*8 +: 8] = in_data[i*8 +: 8];
        end
    endgenerate
endmodule
