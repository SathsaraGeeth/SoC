#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/execution.h"

#include <stdint.h>

static void trace_store(arch_commit_trace_t *trace, uint64_t pc,
                        uint64_t address, uint64_t data, unsigned bytes) {

    uint64_t mask = bytes == sizeof(uint64_t) 
                  ? UINT64_MAX : (UINT64_C(1) << (bytes * 8u)) - 1u;

    if (trace == NULL) 
        return;

    trace->mem_req_we    = 1;
    trace->mem_pc        = pc;
    trace->mem_req_addr  = address;
    trace->mem_req_wdata = (data & mask) << ((address & 7u) * 8u);
    trace->mem_req_wmask = mask << ((address & 7u) * 8u);
}

void iss_execute_load_store(iss_t *iss, dmctp_mnemonic_t mnemonic,
                            uint32_t inst, arch_commit_trace_t *trace) {

    cpu_t *cpu                 = &iss->isa.cpu;
    const uint32_t rd          = dmctp_inst_rd(inst);
    const uint64_t base        = cpu_read_reg(cpu, dmctp_inst_rs1(inst));
    const uint64_t source      = cpu_read_reg(cpu, dmctp_inst_rs2(inst));
    const uint64_t pc          = cpu_read_pc(cpu);
    
    uint64_t address;

    uint64_t data      = 0;
    unsigned bytes     = 0;
    int is_store       = 0;
    int is_reservation = 0;
    int is_conditional = 0;

    switch (mnemonic) {
    case DMCTP_M_LOAD_I8: 
        bytes = 1; 
        data  = (uint64_t)(int64_t)(int8_t)iss->isa.mem_methods
                ->read(&iss->isa, base + dmctp_imm_I(inst), 1); 
        break;
    case DMCTP_M_LOAD_I16: 
        bytes = 2; 
        data  = (uint64_t)(int64_t)(int16_t)iss->isa.mem_methods
                ->read(&iss->isa, base + dmctp_imm_I(inst), 2); 
        break;
    case DMCTP_M_LOAD_I32: 
        bytes = 4; 
        data  = (uint64_t)(int64_t)(int32_t)iss->isa.mem_methods
                ->read(&iss->isa, base + dmctp_imm_I(inst), 4); 
        break;
    case DMCTP_M_LOAD_I64: 
        bytes = 8; 
        data  = iss->isa.mem_methods->read(&iss->isa, base + dmctp_imm_I(inst), 8);
        break;
    case DMCTP_M_LOAD_U8:
        bytes = 1; 
        data = iss->isa.mem_methods->read(&iss->isa, base + dmctp_imm_I(inst), 1);
        break;
    case DMCTP_M_LOAD_U16: 
    case DMCTP_M_LOAD_F16: 
    case DMCTP_M_LOAD_BF16:
        bytes = 2; 
        data  = iss->isa.mem_methods->read(&iss->isa, base + dmctp_imm_I(inst), 2);
        break;
    case DMCTP_M_LOAD_U32: 
        bytes = 4; 
        data  = iss->isa.mem_methods->read(&iss->isa, base + dmctp_imm_I(inst), 4);
        break;
    case DMCTP_M_LOAD_I32_RES: 
    case DMCTP_M_LOAD_I32_RES_AQ:
        bytes = 4; 
        data  = (uint64_t)(int64_t)(int32_t)iss->isa.mem_methods
                ->read(&iss->isa, base, 4); is_reservation = 1; 
        break;
    case DMCTP_M_LOAD_I64_RES: 
    case DMCTP_M_LOAD_I64_RES_AQ:
        bytes = 8; 
        data  = iss->isa.mem_methods->read(&iss->isa, base, 8); 
        is_reservation = 1; 
        break;
    case DMCTP_M_STORE_8: 
        bytes    = 1; 
        is_store = 1; 
        break;
    case DMCTP_M_STORE_16: 
    case DMCTP_M_STORE_F16: 
    case DMCTP_M_STORE_BF16: 
        bytes    = 2; 
        is_store = 1; 
        break;
    case DMCTP_M_STORE_32: 
        bytes    = 4; 
        is_store = 1; 
        break;
    case DMCTP_M_STORE_64: 
        bytes    = 8; 
        is_store = 1; 
        break;
    case DMCTP_M_CONDSTORE_8: 
    case DMCTP_M_CONDSTORE_8_RL: 
        bytes          = 1; 
        is_conditional = 1; 
        break;
    case DMCTP_M_CONDSTORE_16: 
    case DMCTP_M_CONDSTORE_16_RL: 
        bytes = 2; 
        is_conditional = 1; 
        break;
    case DMCTP_M_CONDSTORE_32: 
    case DMCTP_M_CONDSTORE_32_RL: 
        bytes = 4; 
        is_conditional = 1; 
        break;
    case DMCTP_M_CONDSTORE_64: 
    case DMCTP_M_CONDSTORE_64_RL: 
        bytes = 8; 
        is_conditional = 1; 
        break;
    default: 
        cpu_advance_pc(cpu, DMCTP_INST_WIDTH / 8u); 
        return;
    }

    if (is_store) {
        address = base + dmctp_imm_S(inst);
        iss->isa.mem_methods->write(&iss->isa, address, source, bytes);
        trace_store(trace, pc, address, source, bytes);

    } else if (is_conditional) {
        address = base;

        if (iss_store_conditional(iss, address, source, bytes)) {
            trace_store(trace, pc, address, source, bytes);
            cpu_write_reg(cpu, rd, 0, trace);

        } else {
            cpu_write_reg(cpu, rd, 1, trace);
        }
        
    } else {
        address = is_reservation ? base : base + dmctp_imm_I(inst);

        cpu_write_reg(cpu, rd, data, trace);

        if (is_reservation)
            iss->isa.mem_methods->reserve(&iss->isa, address);
    }
    cpu_advance_pc(cpu, DMCTP_INST_WIDTH / 8u);
}
