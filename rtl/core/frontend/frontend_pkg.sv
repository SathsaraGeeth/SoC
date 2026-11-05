/*
 * frontend_pkg.sv
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

package frontend_pkg;

import isa_pkg::*;

typedef union packed {
    struct packed {
        logic [63:0] pc;
        logic [31:0] imm;
        logic [4:0]  rs1; 
        logic [4:0]  rs2; 
    } branch;
    struct packed {
        logic [63:0] pc;
        logic [31:0] imm;
        logic [4:0]  rs1;
        logic [4:0]  rd;
    } jalr;
    struct packed {
        logic [4:0]  padding;
        logic [63:0] pc;
        logic [31:0] imm;
        logic [4:0]  rd;
    } pc_imm_rd;
    struct packed {
        logic [63:0] padding;
        logic [31:0] imm; 
        logic [4:0]  rs1; 
        logic [4:0]  rd; 
    } imm_rs1_rd;
    struct packed {
        logic [63:0] padding; 
        logic [31:0] imm; 
        logic [4:0]  rs1; 
        logic [4:0]  rs2; 
    } imm_rs1_rs2;
    struct packed {
        logic [68:0] padding;
        logic [31:0] imm; 
        logic [4:0]  rd; 
    } imm_rd;
    struct packed { 
        logic [90:0] padding;
        logic [4:0]  rs1; 
        logic [4:0]  rs2;
        logic [4:0]  rd; 
    } rs1_rs2_rd;
    struct packed {
        logic [95:0] padding;
        logic [4:0]  rs1; 
        logic [4:0]  rd; 
    } rs1_rd;
    struct packed {
        logic [85:0] padding;
        logic [4:0]  rs1;
        logic [4:0]  rs2;
        logic [4:0]  rs3;
        logic [4:0]  rd; 
    } rs1_rs2_rs3_rd;
    struct packed {
        logic [83:0] padding;
        logic [11:0] csraddr; 
        logic [4:0]  rs1; 
        logic [4:0]  rd; 
    } csraddr_rs1_rd;
    struct packed { 
        logic [83:0] padding; 
        logic [11:0] csraddr; 
        logic [4:0]  zimm; 
        logic [4:0]  rd; 
    } csraddr_zimm_rd;
} decoded_operands_t;

typedef enum logic [2:0] {
    FU_FLOAT,  FU_LSU,    FU_ALU,
    FU_MUL,    FU_BRANCH, FU_SYSTEM
} functional_unit_e;

typedef enum logic [4:0] {
    FLOAT_ADD,         FLOAT_SUB,         FLOAT_MUL,
    FLOAT_DIV,         FLOAT_SQRT,        FLOAT_MIN,
    FLOAT_MAX,         FLOAT_CMP_EQ,      FLOAT_CMP_LT,
    FLOAT_CMP_LE,      FLOAT_CVT_F2I,     FLOAT_CVT_F2U,
    FLOAT_CVT_I2F,     FLOAT_CVT_U2F,     FLOAT_CVT_F2F16,
    FLOAT_CVT_F16_F,   FLOAT_CVT_F2BF16,  FLOAT_CVT_BF16_F,
    FLOAT_CVT_F2I8,    FLOAT_CVT_F2U8,    FLOAT_CVT_I8_F,
    FLOAT_CVT_U8_F
} float_operation_e;

typedef enum logic [5:0] {
    ALU_ADD,    ALU_ADDI,   ALU_SUB,    ALU_SLL,
    ALU_SLLI,   ALU_SRL,    ALU_SRLI,   ALU_SRA,
    ALU_SRAI,   ALU_SLT,    ALU_SLTI,   ALU_SLTU,
    ALU_SLTIU,  ALU_XOR,    ALU_XORI,   ALU_OR,
    ALU_ORI,    ALU_AND,    ALU_ANDI,   ALU_ADDW,
    ALU_ADDIW,  ALU_SUBW,   ALU_SLLW,   ALU_SLLIW,
    ALU_SRLW,   ALU_SRLIW,  ALU_SRAW,   ALU_SRAIW,
    ALU_LUI,    ALU_AUIPC,  ALU_MUL,    ALU_MULH,
    ALU_MULHU,  ALU_MULHSU, ALU_MULW
} alu_operation_e;

typedef enum logic [3:0] {
    BRANCH_EQ,  BRANCH_NE,  BRANCH_LT, 
    BRANCH_GE,  BRANCH_LTU, BRANCH_GEU, 
    BRANCH_JAL, BRANCH_JALR
} branch_operation_e;

typedef enum logic [3:0] {
    SYSTEM_CSR_RW,  SYSTEM_CSR_RS,  SYSTEM_CSR_RC,
    SYSTEM_CSR_RWI, SYSTEM_CSR_RSI, SYSTEM_CSR_RCI,
    SYSTEM_ECALL,   SYSTEM_SRET,    SYSTEM_MRET,
    SYSTEM_WFI
} system_operation_e;

typedef union packed {
    struct packed {
        logic [0:0]        unused;
        float_operation_e  op;
    } float;
    struct packed {
        logic [0:0]        unused;
        ls_op_e            op;
    } lsu;
    alu_operation_e alu;
    alu_operation_e mul;
    struct packed {
        logic [1:0]        unused;
        branch_operation_e op;
    } branch;
    struct packed {
        logic [1:0]        unused;
        system_operation_e op;
    } system;
} functional_unit_control_u;

typedef struct packed {
    logic irq_timer;
    logic irq_wake;
    logic instr_page_fault;
    logic data_page_fault;
    logic ecall;
    logic mret;
    logic sret;
    logic wfi;
} event_t;

/*
 * Must formally prove for the pipeline this can not
 * wraparound and collide
 */

parameter int EPOCH_W = 8;
typedef logic [EPOCH_W-1:0] epoch_t;

typedef logic [INSTR_W-1:0] raw_instr_t;

typedef struct packed {
    decoded_operands_t         operands;
    functional_unit_e          fu;
    functional_unit_control_u  fu_ctrl;
} decoded_instr_t;

typedef union packed {
    decoded_instr_t decoded;
    raw_instr_t     raw;
    epoch_t         epoch;
} instr_t;

typedef logic [PRIV_MODE_W-1:0] priv_t;

typedef struct packed {
    logic                   waiting_for_fb;
    logic                   waiting_for_consume;
    logic                   waiting_for_mem;
    logic                   waiting_for_wakeup;

    priv_t                  priv_mode;

    logic [XLEN-1:0]        pc;
    instr_t                 instr;
    logic                   is_decoded;
    logic                   is_pc_valid;
    logic                   is_instr_valid;

    logic [XLEN-1:0]        npc;
    raw_instr_t             prefetched_instr;
    logic                   is_npc_valid;
    logic                   is_prefetched_valid;
    
    event_t                 events;
    event_t                 pending_events;
} fe_thrd_state_t;

endpackage: frontend_pkg
