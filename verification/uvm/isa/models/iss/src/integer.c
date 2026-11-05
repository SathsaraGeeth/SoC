/*
 * verification/uvm/isa/models/iss/src/integer.c
 *
 * Copyright (C) 2026 Sathsara Geeth
 *
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

#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/execution.h"

#include <stdint.h>

static uint64_t sext32(uint64_t value) {
    return (uint64_t)(int64_t)(int32_t)(uint32_t)value;
}

static uint64_t mul_high_unsigned(uint64_t a, uint64_t b) {
    uint64_t a0    = (uint32_t)a;
    uint64_t a1    = a >> 32;
    uint64_t b0    = (uint32_t)b;
    uint64_t b1    = b >> 32;
    uint64_t p0    = a0 * b0;
    uint64_t p1    = a0 * b1;
    uint64_t p2    = a1 * b0;
    uint64_t p3    = a1 * b1;
    uint64_t carry = (p0 >> 32) + (uint32_t)p1 + (uint32_t)p2;

    return p3 + (p1 >> 32) + (p2 >> 32) + (carry >> 32);
}

static uint64_t mul_high_signed(uint64_t a, uint64_t b) {
    uint64_t result = mul_high_unsigned(a, b);

    if ((int64_t)a < 0) 
        result -= b;

    if ((int64_t)b < 0) 
        result -= a;

    return result;
}

static uint64_t mul_high_signed_unsigned(uint64_t a, uint64_t b) {
    uint64_t result = mul_high_unsigned(a, b);

    if ((int64_t)a < 0) 
        result -= b;

    return result;
}

void iss_execute_integer(iss_t *iss, dmctp_mnemonic_t mnemonic,
                         uint32_t inst, arch_commit_trace_t *trace) {

    cpu_t          *cpu         = &iss->isa.cpu;
    const uint32_t rd           = dmctp_inst_rd(inst);
    const uint64_t lhs          = cpu_read_reg(cpu, dmctp_inst_rs1(inst));
    const uint64_t reg_rhs      = cpu_read_reg(cpu, dmctp_inst_rs2(inst));
    const uint64_t pc           = cpu_read_pc(cpu);
    const uint64_t imm          = (uint64_t)dmctp_imm_I(inst);
    uint64_t       result       = 0;
    int            write_result = 1;

    switch (mnemonic) {
    case DMCTP_M_BC_EQ:  
        cpu_write_pc(cpu, lhs == reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_BC_NE:  
        cpu_write_pc(cpu, lhs != reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_BC_LT:  
        cpu_write_pc(cpu, (int64_t)lhs < (int64_t)reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_BC_GE:  
        cpu_write_pc(cpu, (int64_t)lhs >= (int64_t)reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_BC_LTU: 
        cpu_write_pc(cpu, lhs < reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_BC_GEU: 
        cpu_write_pc(cpu, lhs >= reg_rhs ? pc + dmctp_imm_B(inst) : pc + DMCTP_INST_WIDTH / 8u); 
        return;
    case DMCTP_M_JUMP_REL_DIR:
        cpu_write_reg(cpu, rd, pc + DMCTP_INST_WIDTH / 8u, trace);
        cpu_write_pc(cpu, pc + dmctp_imm_J(inst)); 
        return;
    case DMCTP_M_AUIPC: 
        result = pc + dmctp_imm_U(inst); 
        break;
    case DMCTP_M_JUMP_ABS:
        cpu_write_reg(cpu, rd, pc + DMCTP_INST_WIDTH / 8u, trace);
        cpu_write_pc(cpu, (lhs + imm) & ~UINT64_C(1)); 
        return;
    case DMCTP_M_LUI: 
        result = (uint64_t)dmctp_imm_U(inst); 
        break;
    case DMCTP_M_ADD_I64: 
        result = lhs + reg_rhs; 
        break;
    case DMCTP_M_ADDI_I64: 
        result = lhs + imm; 
        break;
    case DMCTP_M_ADD_I32: 
        result = sext32(lhs + reg_rhs); 
        break;
    case DMCTP_M_ADDI_I32: 
        result = sext32(lhs + imm); 
        break;
    case DMCTP_M_SUB_I64: 
        result = lhs - reg_rhs; 
        break;
    case DMCTP_M_SUB_I32: 
        result = sext32(lhs - reg_rhs); 
        break;
    case DMCTP_M_MUL_64_LO: 
        result = lhs * reg_rhs; 
        break;
    case DMCTP_M_MUL_I64_HI: 
        result = mul_high_signed(lhs, reg_rhs); 
        break;
    case DMCTP_M_MUL_IU64_HI: 
        result = mul_high_signed_unsigned(lhs, reg_rhs); 
        break;
    case DMCTP_M_MUL_U64_HI: 
        result = mul_high_unsigned(lhs, reg_rhs); 
        break;
    case DMCTP_M_MUL_I32_LO: 
        result = sext32(lhs * reg_rhs); 
        break;
    case DMCTP_M_SL_I64: 
        result = lhs << (reg_rhs & (DMCTP_XLEN - 1u)); 
        break;
    case DMCTP_M_SLI_I64: 
        result = lhs << (imm & (DMCTP_XLEN - 1u)); 
        break;
    case DMCTP_M_SL_I32: 
        result = sext32((uint32_t)lhs << (reg_rhs & 31u)); 
        break;
    case DMCTP_M_SLI_I32: 
        result = sext32((uint32_t)lhs << (imm & 31u)); 
        break;
    case DMCTP_M_SR_U64: 
        result = lhs >> (reg_rhs & (DMCTP_XLEN - 1u)); 
        break;
    case DMCTP_M_SR_I64: 
        result = (uint64_t)((int64_t)lhs >> (reg_rhs & (DMCTP_XLEN - 1u))); 
        break;
    case DMCTP_M_SRI_U64: 
        result = lhs >> (imm & (DMCTP_XLEN - 1u)); 
        break;
    case DMCTP_M_SRI_I64: 
        result = (uint64_t)((int64_t)lhs >> (imm & (DMCTP_XLEN - 1u))); 
        break;
    case DMCTP_M_SR_U32: 
        result = sext32((uint32_t)lhs >> (reg_rhs & 31u)); 
        break;
    case DMCTP_M_SR_I32: 
        result = sext32((uint32_t)((int32_t)lhs >> (reg_rhs & 31u))); 
        break;
    case DMCTP_M_SRI_U32: 
        result = sext32((uint32_t)lhs >> (imm & 31u)); 
        break;
    case DMCTP_M_SRI_I32: 
        result = sext32((uint32_t)((int32_t)lhs >> (imm & 31u))); 
        break;
    case DMCTP_M_AND_64: 
        result = lhs & reg_rhs; 
        break;
    case DMCTP_M_ANDI_64: 
        result = lhs & imm; 
        break;
    case DMCTP_M_OR_64: 
        result = lhs | reg_rhs; 
        break;
    case DMCTP_M_ORI_64: 
        result = lhs | imm; 
        break;
    case DMCTP_M_XOR_64: 
        result = lhs ^ reg_rhs; 
        break;
    case DMCTP_M_XORI_64: 
        result = lhs ^ imm; 
        break;
    case DMCTP_M_SLT_I64: 
        result = (int64_t)lhs < (int64_t)reg_rhs; 
        break;
    case DMCTP_M_SLT_U64: 
        result = lhs < reg_rhs; 
        break;
    case DMCTP_M_SLTI_I64: 
        result = (int64_t)lhs < (int64_t)imm; 
        break;
    case DMCTP_M_SLTI_U64: 
        result = lhs < imm; 
        break;
    default: 
        write_result = 0; 
        break;
    }

    if (write_result) 
        cpu_write_reg(cpu, rd, result, trace);

    cpu_advance_pc(cpu, DMCTP_INST_WIDTH / 8u);
}
