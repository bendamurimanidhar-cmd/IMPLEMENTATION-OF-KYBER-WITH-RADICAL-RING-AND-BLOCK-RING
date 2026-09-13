`timescale 1ns / 1ps
module keccak_round (
    input  wire [1599:0] state_in_flat,
    input  wire [4:0]    round_idx,    
    output wire [1599:0] round_out_flat
);
    wire [1599:0] theta_out;
    wire [1599:0] rho_out;
    wire [1599:0] pi_out;
    wire [1599:0] chi_out;
    keccak_theta step_theta (
        .state_in_flat(state_in_flat),
        .theta_out_flat(theta_out)
    );
    keccak_rho step_rho (
        .state_in_flat(theta_out),
        .rho_out_flat(rho_out)
    );
    keccak_pi step_pi (
        .state_in_flat(rho_out),
        .pi_out_flat(pi_out)
    );
    keccak_chi step_chi (
        .state_in_flat(pi_out),
        .chi_out_flat(chi_out)
    );
    keccak_iota step_iota (
        .state_in_flat(chi_out),
        .round_idx(round_idx),
        .iota_out_flat(round_out_flat)
    );
endmodule
