/*
 * Comment:
 * 1. In the tb/ only this file is not agnostic
 *    to the core's internal signals
 *    so have to keep this insync with the 
 *    rtl/core/ design
 * 2. To where to bind?
 *    Should bind to the architectural commit points
 *    e.g. not to the physical register file
 *         but in to the ROB's commiting head
 */

import core_pkg::*;

module commit_binder (
    input logic clk,
    input logic rst_n
);
    commit_if iface(clk, rst_n);

    generate
        for (genvar t = 0; t < NUM_HW_THRDS; t++) begin
            logic [core_pkg::VIR_ADDR_W-1:0] store_addr;
            logic [core_pkg::XLEN/8-1:0]     store_wstrb;
            logic [core_pkg::XLEN-1:0]       store_wmask;
            logic [core_pkg::XLEN-1:0]       store_wdata;

            always_comb begin
                store_addr = core.r_rob_instr[t].rs1_data +
                             core.r_rob_instr[t].instr.imm;
                store_wstrb = '0;

                unique case (core.r_rob_instr[t].instr.ls_op)
                    LS_STORE_8,
                    LS_CSTORE_8,
                    LS_CSTORE_8_RL:
                        store_wstrb = (core_pkg::XLEN/8)'(1) <<
                                      store_addr[$clog2(core_pkg::XLEN/8)-1:0];
                    LS_STORE_32,
                    LS_CSTORE_32,
                    LS_CSTORE_32_RL:
                        store_wstrb = (core_pkg::XLEN/8)'(4'hf) <<
                                      (store_addr[$clog2(core_pkg::XLEN/8)-1] * 4);
                    LS_STORE_64,
                    LS_CSTORE_64,
                    LS_CSTORE_64_RL:
                        store_wstrb = '1;
                    default:
                        store_wstrb = (core_pkg::XLEN/8)'(2'b11) <<
                                      (store_addr[$clog2(core_pkg::XLEN/8)-1:1] * 2);
                endcase

                store_wmask = '0;
                for (int i = 0; i < core_pkg::XLEN/8; i++)
                    store_wmask[i*8 +: 8] = {8{store_wstrb[i]}};

                store_wdata = core.r_rob_instr[t].rs2_data <<
                              (store_addr[$clog2(core_pkg::XLEN/8)-1:0] * 8);
            end

            /* pc commits */
            assign iface.commit_valid[t]  = core.w_commit_valid_vec[t] &&
                                            !(core.w_commit_found &&
                                              core.w_commit_thrd_id == t &&
                                              core.s0_p3_stall_commit_for_tlb);
            assign iface.commit_pc[t]     = core.r_rob_instr[t].instr.pc;
            /* reg file commits */
            assign iface.rf_we[t]         = core.w_regfile_we_vec[t];
            assign iface.rf_we_addr[t]    = core.w_regfile_rd_addr_vec[t];
            assign iface.rf_we_data[t]    = core.w_regfile_rd_wdata_vec[t];
            assign iface.rf_pc[t]         = core.r_rob_instr[t].instr.pc;
            /* csr commits */
            assign iface.csr_we[t]        = core.w_csr_we && (core.w_csr_wthrd_id == t);
            assign iface.csr_we_addr[t]   = core.w_csr_rd_addr;
            assign iface.csr_we_data[t]   = core.w_csr_rd_wdata;
            assign iface.csr_pc[t]        = core.r_rob_instr[t].instr.pc;
            /* memory commits */
            assign iface.mem_req_we[t]    = iface.commit_valid[t] &&
                                            !core.r_rob_instr[t].instr.is_page_fault &&
                                            core.r_rob_instr[t].instr.fu == FU_LSU &&
                                            core.r_rob_instr[t].instr.ls_wen &&
                                            (!core.r_rob_instr[t].instr.ls_sc ||
                                             core.r_lsu_resp_sc_ok_vec[t]);
            assign iface.mem_req_addr[t]  = store_addr;
            assign iface.mem_req_wdata[t] = store_wdata & store_wmask;
            assign iface.mem_req_wmask[t] = store_wmask;
            assign iface.mem_pc[t]        = core.r_rob_instr[t].instr.pc;
        end
    endgenerate

endmodule: commit_binder
