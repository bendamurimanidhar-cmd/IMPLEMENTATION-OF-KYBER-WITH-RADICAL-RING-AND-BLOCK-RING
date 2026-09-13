`timescale 1ns / 1ps
module mont_mult #(
    parameter Q = 3329,     
    parameter Q_inv = 3327, 
    parameter rsh = 12      
)(
    input  wire [11:0] a,   
    input  wire [11:0] b,   
    output wire [11:0] c    
);
    wire [23:0] t = a * b;
    wire [11:0] t_low = t[11:0]; 
    wire [11:0] m_sum1 = (t_low << 11) + (t_low << 10);
    wire [11:0] m_sum2 = (t_low << 8) - t_low;
    wire [11:0] m = m_sum1 + m_sum2;
    wire [23:0] q_sum1 = (m << 11) + (m << 10);
    wire [23:0] q_sum2 = (m << 8) + m;
    wire [23:0] m_times_q = q_sum1 + q_sum2;
    wire [24:0] u_raw = t + m_times_q;
    wire [12:0] u = u_raw[24:rsh]; 
    wire [12:0] u_sub_q = u - Q[12:0]; 
    assign c = u_sub_q[12] ? u[11:0] : u_sub_q[11:0];
endmodule
