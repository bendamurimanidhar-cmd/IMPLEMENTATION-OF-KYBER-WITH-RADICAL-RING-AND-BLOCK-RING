`timescale 1ns / 1ps
module keccak_shared_hub (
    input  wire          clk,
    input  wire          rst_n,
    input  wire          start_absorb,  
    input  wire          start_squeeze, 
    input  wire [1:0]    mode,          
    input  wire [511:0]  din,           
    output wire          ready,         
    output wire          dout_valid,    
    output wire [1343:0] dout           
);
    reg [1599:0] padded_state;
    localparam [7:0] PAD_SHA3  = 8'h06; 
    localparam [7:0] PAD_SHAKE = 8'h1F; 
    localparam [7:0] PAD_END   = 8'h80; 
    always @(*) begin
        padded_state = 1600'b0; 
        case (mode)
            2'b00: begin
                padded_state[575:0] = {PAD_END, 296'd0, PAD_SHA3, din[263:0]};
            end
            2'b01: begin
                padded_state[1343:0] = {PAD_END, 1056'd0, PAD_SHAKE, din[271:0]};
            end
            2'b10: begin
                padded_state[1087:0] = {PAD_END, 808'd0, PAD_SHAKE, din[263:0]};
            end
            default: padded_state = 1600'b0;
        endcase
    end
    wire [1599:0] permuted_state;
    wire          perm_ready;
    wire          perm_done;
    wire [1599:0] core_input_state = start_absorb ? padded_state : permuted_state;
    wire core_start = start_absorb | start_squeeze;
    keccak_permutation u_perm_core (
        .clk            (clk),
        .rst_n          (rst_n),
        .start          (core_start),
        .state_in_flat  (core_input_state),
        .ready          (perm_ready),
        .done           (perm_done),
        .state_out_flat (permuted_state)
    );
    assign dout = permuted_state[1343:0];
    assign ready = perm_ready;
    assign dout_valid = perm_done;
endmodule
