`default_nettype none
module circular_buffer #(parameter DEPTH=4,parameter WIDTH=8)(
 input logic i_clk,input logic i_rst_n,output logic[WIDTH-1:0]o_head_data,
 output logic o_deq_ready,input logic i_deq_valid,input logic[WIDTH-1:0]i_enq_tail_data,
 input logic i_enq_valid,output logic o_enq_ready,output logic o_full,output logic o_empty,
 output logic[$clog2(DEPTH+1)-1:0]o_level,input logic i_clr_n);
 assign o_head_data='0;assign o_deq_ready=1'b0;assign o_enq_ready=1'b1;
 assign o_full=1'b0;assign o_empty=1'b1;assign o_level='0;
endmodule

module sys_address_generator#(parameter IS_WB=0,parameter IS_B=0)(
 input logic i_clk,input logic i_rst_n,input logic i_start,input logic[63:0]i_tid,
 input logic[63:0]i_base_addr,input logic[15:0]i_a_tiles,input logic[15:0]i_b_tiles,
 input logic i_dense,input logic i_cmd_start,input logic i_cmd_last,
 input sys_cnfg_pkg::mac_t i_mac_type,input logic i_addr_enq_ready,
 output logic o_addr_enq_valid,
 output logic[sys_cnfg_pkg::VIR_ADDR_W+sys_cnfg_pkg::XLEN+$bits(sys_cnfg_pkg::mac_t)+sys_cnfg_pkg::ADDR_FLAGS_W+1:0]o_addr_enq_data,
 output logic o_done);
 assign o_addr_enq_valid=1'b0;assign o_addr_enq_data='0;assign o_done=1'b0;
endmodule

module mmacu_core_v2#(parameter sys_cnfg_pkg::mac_static_t MAC_STATIC_TYPE=sys_cnfg_pkg::MAC_T)(
 input logic i_clk,input logic i_rst_n,input logic i_dense,input sys_cnfg_pkg::mac_t i_mac_type,
 input logic[$clog2(sys_cnfg_pkg::K+1)-1:0]i_k2,input logic i_start,input logic i_last,input logic i_end,
 input logic[sys_cnfg_pkg::M*sys_cnfg_pkg::WIDTH_AB-1:0]i_a,input logic[sys_cnfg_pkg::M*sys_cnfg_pkg::WIDTH_AB-1:0]i_b,
 input logic i_a_valid,input logic i_b_valid,output logic o_a_ready,output logic o_b_ready,
 output logic[sys_cnfg_pkg::M*sys_cnfg_pkg::WIDTH_CD-1:0]o_d,output logic o_d_valid,input logic i_d_ready);
 assign o_a_ready=i_b_valid;assign o_b_ready=i_a_valid;assign o_d='0;assign o_d_valid=1'b0;
endmodule
`default_nettype wire

