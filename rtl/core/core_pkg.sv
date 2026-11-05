/*
 * core_pkg.sv
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

`timescale 1ns/1ps
`default_nettype none
package core_pkg;

import isa_pkg::*;

parameter int XLEN              = isa_pkg::XLEN;
parameter int REG_COUNT         = isa_pkg::REG_COUNT;
parameter int REG_BITS          = isa_pkg::REG_BITS;
parameter int VIR_ADDR_W             = isa_pkg::XLEN;

parameter int NUM_HW_THRDS           = 4;
parameter int ISSUE_Q_DEPTH     = 32;
parameter int FU_Q_DEPTH        = 8;
parameter int FU_COUNT          = 6;
parameter int CSR_COUNT         = isa_pkg::CSR_COUNT;

typedef struct packed {
    logic                               valid;
    logic [INST_W-1:0]                  instr;
    logic                               is_pf;
    logic [isa_pkg::TRAP_CAUSE_W-1:0]   pf_cause;
} fetched_instr_t;

typedef enum logic [$clog2(CSR_COUNT)-1:0] {
    CSR_MSTATUS         = isa_pkg::CSR_SLOT_MSTATUS,
    CSR_MIE             = isa_pkg::CSR_SLOT_MIE,
    CSR_MIP             = isa_pkg::CSR_SLOT_MIP,
    CSR_MEPC            = isa_pkg::CSR_SLOT_MEPC,
    CSR_MCAUSE          = isa_pkg::CSR_SLOT_MCAUSE,
    CSR_MTVEC           = isa_pkg::CSR_SLOT_MTVEC,
    CSR_MSCRATCH        = isa_pkg::CSR_SLOT_MSCRATCH,
    CSR_FCSR            = isa_pkg::CSR_SLOT_FCSR,
    CSR_THREAD_ID       = isa_pkg::CSR_SLOT_THREAD_ID,
    CSR_VIRTUAL_THRD_ID = isa_pkg::CSR_SLOT_VIRTUAL_THRD_ID,
    CSR_SATP            = isa_pkg::CSR_SLOT_SATP,
    CSR_PAGE_MSG_ARG0   = isa_pkg::CSR_SLOT_PAGE_MSG_ARG0,
    CSR_PAGE_MSG_ARG1   = isa_pkg::CSR_SLOT_PAGE_MSG_ARG1,
    CSR_PAGE_MSG_CMD    = isa_pkg::CSR_SLOT_PAGE_MSG_CMD,
    CSR_SSTATUS         = isa_pkg::CSR_SLOT_SSTATUS,
    CSR_SIE             = isa_pkg::CSR_SLOT_SIE,
    CSR_SIP             = isa_pkg::CSR_SLOT_SIP,
    CSR_SEPC            = isa_pkg::CSR_SLOT_SEPC,
    CSR_SCAUSE          = isa_pkg::CSR_SLOT_SCAUSE,
    CSR_STVAL           = isa_pkg::CSR_SLOT_STVAL,
    CSR_STVEC           = isa_pkg::CSR_SLOT_STVEC,
    CSR_SSCRATCH        = isa_pkg::CSR_SLOT_SSCRATCH,
    CSR_MEDELEG         = isa_pkg::CSR_SLOT_MEDELEG,
    CSR_MIDELEG         = isa_pkg::CSR_SLOT_MIDELEG
} csr_addr_e;

function automatic logic [$clog2(CSR_COUNT)-1:0] csr_addr_decode(input logic [isa_pkg::CSR_ADDR_W-1:0] addr);
    case (addr)
        isa_pkg::CSR_MSTATUS:         return CSR_MSTATUS;
        isa_pkg::CSR_MIE:             return CSR_MIE;
        isa_pkg::CSR_MIP:             return CSR_MIP;
        isa_pkg::CSR_MEPC:            return CSR_MEPC;
        isa_pkg::CSR_MCAUSE:          return CSR_MCAUSE;
        isa_pkg::CSR_MTVEC:           return CSR_MTVEC;
        isa_pkg::CSR_MSCRATCH:        return CSR_MSCRATCH;
        isa_pkg::CSR_FCSR:            return CSR_FCSR;
        isa_pkg::CSR_THREAD_ID:       return CSR_THREAD_ID;
        isa_pkg::CSR_VIRTUAL_THRD_ID: return CSR_VIRTUAL_THRD_ID;
        isa_pkg::CSR_PAGE_MSG_ARG0:   return CSR_PAGE_MSG_ARG0;
        isa_pkg::CSR_PAGE_MSG_ARG1:   return CSR_PAGE_MSG_ARG1;
        isa_pkg::CSR_PAGE_MSG_CMD:    return CSR_PAGE_MSG_CMD;
        isa_pkg::CSR_SSTATUS:          return CSR_SSTATUS;
        isa_pkg::CSR_SIE:              return CSR_SIE;
        isa_pkg::CSR_SIP:              return CSR_SIP;
        isa_pkg::CSR_SEPC:             return CSR_SEPC;
        isa_pkg::CSR_SCAUSE:           return CSR_SCAUSE;
        isa_pkg::CSR_STVAL:            return CSR_STVAL;
        isa_pkg::CSR_STVEC:            return CSR_STVEC;
        isa_pkg::CSR_SSCRATCH:         return CSR_SSCRATCH;
        isa_pkg::CSR_MEDELEG:          return CSR_MEDELEG;
        isa_pkg::CSR_MIDELEG:          return CSR_MIDELEG;
        default:                      return '0;
    endcase
endfunction

typedef enum logic [2:0] {
    FU_ALU  = 3'b000,
    FU_FPU  = 3'b001,
    FU_LSU  = 3'b010,
    FU_MCU  = 3'b011,
    FU_CSR  = 3'b100,
    FU_BRU  = 3'b101
} fu_e;

typedef enum logic [1:0] {
    RAWHZ_NONE        = 2'b00,
    RAWHZ_RS1         = 2'b01,
    RAWHZ_RS1_RS2     = 2'b10,
    RAWHZ_RS1_RS2_RS3 = 2'b11
} rawhz_e;

typedef struct packed {
    logic [INST_W-1:0]                raw;
    logic [XLEN-1:0]                  pc;
    logic                             is_branch;   // conditional branch
    logic                             is_jump;     // JAL or JALR
    logic                             is_jalr;
    logic                             is_ecall;
    logic                             is_sret;
    logic                             is_mret;
    logic                             is_wfi;
    logic                             use_imm;
    logic                             use_pc;
    logic                             alu_word;   // RV64 OP-32 / OP-IMM-32, sign-extended result
    logic                             ls_unsigned; // unsigned load
    logic [REG_BITS-1:0]              rs1;
    logic [REG_BITS-1:0]              rs2;
    logic [REG_BITS-1:0]              rs3;
    logic [REG_BITS-1:0]              rd;
    logic [XLEN-1:0]                  imm;         // sgn extended
    logic [FUNCT3_W-1:0]              funct3;
    fu_e                              fu;          // functional unit
    rawhz_e                           rawhz_t;     // source register hazard check class
    alu_op_e                          alu_op;
    fpu_op_e                          fpu_op;
    ls_op_e                           ls_op;
    logic                             ls_wen;     // load/store write enable
    logic                             ls_lq;
    logic                             ls_sc;
    logic                             rf_wen;
    logic                             csr_wen;
    logic                             is_page_fault;
    logic [TRAP_CAUSE_W-1:0]          trap_cause;
} decoded_instr_t;

typedef struct packed {
    decoded_instr_t                   instr;
    logic [$clog2(NUM_HW_THRDS)-1:0]  thrd_id;
    logic [XLEN-1:0]                  rs1_data;
    logic [XLEN-1:0]                  rs2_data;
    logic [XLEN-1:0]                  rs3_data;
    logic [XLEN-1:0]                  csr_data;
    logic                             trap_to_s;
} issue_instr_t;

endpackage: core_pkg
