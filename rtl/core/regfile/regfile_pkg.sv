/*
 * reg_bank.sv
 * 
 * Copyright (C) 2026 Sathsara Geeth
 */

/*
 * Version 1.0
 *
 * Version History
 *
 * Version | Description
 * --------+-----------------------------------------
 * 1.0     | Initial implementation
 */

package regfile_pkg;

import core_pkg::*;

parameter int NUM_REGS   = REG_COUNT*NUM_HW_THRDS;
parameter int REG_ADDR_W = $clog2(NUM_REGS);

typedef struct packed {
    logic [REG_ADDR_W-1:0]  rs1_addr;
    logic [REG_ADDR_W-1:0]  rs2_addr;
    logic [REG_ADDR_W-1:0]  rs3_addr;
    logic [2:0]             read_mask;
} reg_read_req_t;

typedef struct packed {
    logic [XLEN-1:0]  rs1_data;
    logic [XLEN-1:0]  rs2_data;
    logic [XLEN-1:0]  rs3_data;
} reg_read_resp_t;

function automatic logic is_zero_reg(input logic [REG_ADDR_W-1:0] addr);
    return addr[$clog2(REG_COUNT)-1:0] == '0;
endfunction

endpackage: regfile_pkg
