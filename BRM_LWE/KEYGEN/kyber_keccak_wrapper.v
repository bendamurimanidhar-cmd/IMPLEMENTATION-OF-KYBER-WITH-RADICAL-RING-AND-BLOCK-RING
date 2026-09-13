`timescale 1ns / 1ps
module kyber_keccak_wrapper (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          cmd_hash_seed,   
    input  wire          cmd_gen_vector,  
    input  wire          cmd_gen_matrix,  
    input  wire          cmd_squeeze_more,
    input  wire [255:0]  seed_in,         
    input  wire [7:0]    k_param,         
    input  wire [255:0]  sigma,           
    input  wire [7:0]    nonce,           
    input  wire [255:0]  rho,             
    input  wire [7:0]    i_idx,           
    input  wire [7:0]    j_idx,           
    output wire          ready,           
    output wire          dout_valid,      
    output wire [511:0]  sha3_out,        
    output wire [1343:0] shake_out        
);
    wire [263:0] swapped_seed_full;
    wire [255:0] swapped_sigma;
    wire [271:0] swapped_matrix_full; 
    endian_swap #(.DATA_BITS(264)) swap_seed_full (
        .in_data({seed_in, k_param}),
        .out_data(swapped_seed_full)
    );
    endian_swap #(.DATA_BITS(256)) swap_sigma_only (
        .in_data(sigma),
        .out_data(swapped_sigma)
    );
    endian_swap #(.DATA_BITS(272)) swap_matrix_full (
        .in_data({rho, j_idx, i_idx}), 
        .out_data(swapped_matrix_full)
    );
    reg [1:0]   hub_mode;
    reg [511:0] hub_din;
    wire        hub_start_absorb = cmd_hash_seed | cmd_gen_vector | cmd_gen_matrix;
    always @(*) begin
        hub_mode = 2'b00;
        hub_din  = 512'd0;
        if (cmd_hash_seed) begin
            hub_mode = 2'b00; 
            hub_din  = {248'd0, swapped_seed_full}; 
        end 
        else if (cmd_gen_vector) begin
            hub_mode = 2'b10; 
            hub_din  = {248'd0, nonce, swapped_sigma};
        end 
        else if (cmd_gen_matrix) begin
            hub_mode = 2'b01; 
            hub_din  = {240'd0, swapped_matrix_full};
        end
    end
    wire [1343:0] raw_hub_dout;
    keccak_shared_hub u_hub (
        .clk           (clk),
        .rst_n         (rst_n),
        .start_absorb  (hub_start_absorb),
        .start_squeeze (cmd_squeeze_more),
        .mode          (hub_mode),
        .din           (hub_din),
        .ready         (ready),
        .dout_valid    (dout_valid),
        .dout          (raw_hub_dout)
    );
    assign shake_out = raw_hub_dout;
    endian_swap #(.DATA_BITS(512)) swap_sha3_out (
        .in_data(raw_hub_dout[511:0]),
        .out_data(sha3_out)
    );
endmodule
