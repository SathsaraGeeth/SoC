#include "../include/iss.h"
#include "include/cpu_impl.h"
#include "include/execution.h"

void iss_execute_system(iss_t *iss, dmctp_mnemonic_t mnemonic,
                        uint32_t inst, arch_commit_trace_t *trace)
{
    cpu_t *cpu                 = &iss->isa.cpu;
    const uint32_t rd          = dmctp_inst_rd(inst);
    const uint32_t rs1         = dmctp_inst_rs1(inst);
    const uint32_t csr_address = (uint32_t)dmctp_uimm_I(inst);
    const uint64_t old_value   = cpu_read_csr(cpu, csr_address);
    const uint64_t source      = cpu_read_reg(cpu, rs1);
    uint64_t new_value         = old_value;
    int write_csr              = 1;

    switch (mnemonic) {
    case DMCTP_M_CSRRW: 
        new_value = source; 
        break;
    case DMCTP_M_CSRRWI: 
        new_value = rs1; 
        break;
    case DMCTP_M_CSRRS: 
        new_value = old_value | source; 
        write_csr = rs1 != 0; 
        break;
    case DMCTP_M_CSRRC: 
        new_value = old_value & ~source; 
        write_csr = rs1 != 0; 
        break;
    case DMCTP_M_CSRRSI: 
        new_value = old_value | rs1; 
        write_csr = rs1 != 0; 
        break;
    case DMCTP_M_CSRRCI: 
        new_value = old_value & ~((uint64_t)rs1); 
        write_csr = rs1 != 0; 
        break;
    default: 
        write_csr = 0; 
        break;
    }
    cpu_write_reg(cpu, rd, old_value, trace);

    if (write_csr) 
        cpu_write_csr(cpu, csr_address, new_value, trace);

    cpu_advance_pc(cpu, DMCTP_INST_WIDTH / 8u);
}
