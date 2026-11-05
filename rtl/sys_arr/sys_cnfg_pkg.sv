`timescale 1ns/1ps
`default_nettype none

package sys_cnfg_pkg;

typedef enum logic [1:0] {
    MAC20I_STATIC,
    MACFP8_STATIC,
    MACFP8INT8_STATIC
} mac_static_t;

typedef enum logic [1:0] {
    MAC20I,
    MACFP8
} mac_t;

parameter int MAC_W                 = $bits(mac_t);
parameter int WORD_W                = 1 << 3;
parameter int M                      = 8;
parameter mac_static_t MAC_T             = MACFP8INT8_STATIC;
parameter int WIDTH_AB              = WORD_W;
parameter int WIDTH_CD              = WORD_W;
parameter int VEC_W                 = M * WORD_W;
parameter int MAX_DENSE_MAT_SZ       = 256;
parameter int K                      = MAX_DENSE_MAT_SZ / M;

function automatic int mac_latency(input mac_t mac_type);
    case (mac_type)
        MAC20I: return 6;
        MACFP8: return 13;
    endcase
endfunction

function automatic int mac_output_cycle(input mac_t mac_type, input int b_tiles);
    return 2*M + mac_latency(mac_type) - 3 -
           (((mac_type == MACFP8) && (b_tiles > 1)) ? 1 : 0);
endfunction

function automatic int mac_flush(input mac_t mac_type);
    case (mac_type)
        MAC20I: return 10*M+6+1;
        MACFP8: return 10*M+13+1+4;
    endcase
endfunction

localparam int FLUSH_W      = 16;   /* conservative */

parameter int CMD_W                 = 1 << 8;
parameter int VIR_ADDR_W            = core_pkg::VIR_ADDR_W;
parameter int PORT_W                = memory_pkg::PORT_W;
parameter int XLEN                  = PORT_W;
parameter int NUM_PORTS             = 3;
parameter int OP_BUFF_D             = 16;
parameter int CMD_BUFF_D            = 16;
parameter int RES_BUFF_D            = 64;
parameter int CMD_FLAG_W            = 8;
parameter int CMD_FLAG_PAD_W        = 24;
parameter int CMD_FLAG_CONTAINER_W  = CMD_FLAG_W + CMD_FLAG_PAD_W;
parameter int A_ADDR_BUFF           = 16;
parameter int B_ADDR_BUFF           = 16;
parameter int D_ADDR_BUFF           = 64;
parameter int VEC_BYTES             = VEC_W / 8;
parameter int DEFAULT_TILES         = 1;
parameter int TILE_W                = 16;
parameter int ADDR_FLAGS_W          = 3;

parameter logic [ADDR_FLAGS_W-1:0] ADDR_FLAGS_NONE     = '0;
parameter logic [ADDR_FLAGS_W-1:0] ADDR_FLAGS_END      = 3'b100;
parameter logic [ADDR_FLAGS_W-1:0] ADDR_FLAGS_CONTINUE = {ADDR_FLAGS_W{1'b1}};

parameter logic [7:0] CMD_TYPE_I   = 8'h01;
parameter logic [7:0] CMD_TYPE_II  = 8'h02;
parameter logic [7:0] CMD_TYPE_III = 8'h03;
parameter logic [7:0] CMD_TYPE_IV  = 8'h04;
parameter int CMD_MAC_TYPE_LSB     = 19;

function automatic logic [7:0] get_cmd_typeid(input logic [CMD_W-1:0] cmd);
    return cmd[31:24];
endfunction
function automatic logic [VIR_ADDR_W-1:0] calc_a_addr(
    input logic [VIR_ADDR_W-1:0] base_addr,
    input logic [15:0] q_idx,
    input logic [2:0] beat,
    input logic [15:0] a_tiles_limit,
    input logic [15:0] a_idx
);
    return base_addr + (((VIR_ADDR_W'(q_idx) * M + VIR_ADDR_W'(beat)) * VIR_ADDR_W'(a_tiles_limit) + VIR_ADDR_W'(a_idx)) * VEC_BYTES);
endfunction
function automatic logic [VIR_ADDR_W-1:0] calc_b_addr(
    input logic [VIR_ADDR_W-1:0] base_addr,
    input logic [15:0] q_idx,
    input logic [2:0] beat,
    input logic [15:0] b_tiles_limit,
    input logic [15:0] b_idx
);
    return base_addr + (((VIR_ADDR_W'(q_idx) * M + VIR_ADDR_W'(beat)) * VIR_ADDR_W'(b_tiles_limit) + VIR_ADDR_W'(b_idx)) * VEC_BYTES);
endfunction
function automatic logic [VIR_ADDR_W-1:0] calc_d_addr(
    input logic [VIR_ADDR_W-1:0] base_addr,
    input logic [15:0] a_idx,
    input logic [2:0] beat,
    input logic [15:0] b_tiles_limit,
    input logic [15:0] b_idx
);
    return base_addr + (((VIR_ADDR_W'(a_idx) * M + VIR_ADDR_W'(beat)) * VIR_ADDR_W'(b_tiles_limit) + VIR_ADDR_W'(b_idx)) * VEC_BYTES);
endfunction
function automatic logic is_cmd_op(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I);
endfunction
function automatic logic is_cmd_dense(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I) && cmd[21];
endfunction
function automatic logic is_cmd_start(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I) && cmd[23];
endfunction
function automatic logic is_cmd_last(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I) && cmd[22];
endfunction
function automatic logic is_cmd_start_last(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I) && cmd[23] && cmd[22];
endfunction
function automatic logic is_cmd_delegation(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_III);
endfunction
function automatic logic is_cmd_wb(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_II);
endfunction
function automatic logic is_cmd_dense_wb(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_II) && cmd[23];
endfunction
function automatic logic is_cmd_release(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_IV);
endfunction
function automatic mac_t get_cmd_mac_type(input logic [CMD_W-1:0] cmd);
    case (MAC_T)
        MAC20I_STATIC: return MAC20I;
        MACFP8_STATIC: return MACFP8;
        default:       return mac_t'(cmd[CMD_MAC_TYPE_LSB +: $bits(mac_t)]);
    endcase
endfunction
function automatic logic is_cmd_op_last(input logic [CMD_W-1:0] cmd);
    return (get_cmd_typeid(cmd) == CMD_TYPE_I) && cmd[22];
endfunction
function automatic logic [$clog2(K+1)-1:0] get_cmd_a_size(input logic [CMD_W-1:0] cmd);
    return ($clog2(K+1))'(cmd[63:48]);
endfunction
function automatic logic [$clog2(K+1)-1:0] get_cmd_b_size(input logic [CMD_W-1:0] cmd);
    return ($clog2(K+1))'(cmd[47:32]);
endfunction
function automatic logic [XLEN-1:0] get_cmd_tid(input logic [CMD_W-1:0] cmd);
    return XLEN'(cmd[191:128]);
endfunction
function automatic logic [XLEN-1:0] get_cmd_vtid(input logic [CMD_W-1:0] cmd);
    return XLEN'(cmd[127:64]);
endfunction
function automatic logic [VIR_ADDR_W-1:0] get_cmd_a_addr(input logic [CMD_W-1:0] cmd);
    return VIR_ADDR_W'(cmd[127:64]);
endfunction
function automatic logic [VIR_ADDR_W-1:0] get_cmd_b_addr(input logic [CMD_W-1:0] cmd);
    return VIR_ADDR_W'(cmd[191:128]);
endfunction
function automatic logic [VIR_ADDR_W-1:0] get_cmd_d_addr(input logic [CMD_W-1:0] cmd);
    return VIR_ADDR_W'(cmd[127:64]);
endfunction
endpackage: sys_cnfg_pkg
