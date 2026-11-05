/* 
 * verification/uvm/isa/scoreboard.sv
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

/*
 * Comments:
 * 1. Asserts the equivalance with the ISS
 *     A. csr updates:
 *        - inorder
 *        - equivalant
 *     B. gpr:
 *        - inorder
 *        - equivalent
 *     C. memory:
 *        - equivalent when the test exists
 *        - no need to be equivalent in each event
 *          nor need to inorder neither same number
 *          of transactions
 *        - the memory is not a shared between the
 *          each threads. so they have different
 *          memory space, which may be intersected
 *          or not. why?
 */
  

`include "uvm_macros.svh"
import uvm_pkg::*;
import iss_dpi_pkg::*;

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    typedef struct {
        logic [core_pkg::XLEN-1:0] pc;
        int unsigned               address;
        logic [core_pkg::XLEN-1:0] data;
    } expected_rf_t;

    typedef struct {
        logic [core_pkg::XLEN-1:0] pc;
        int unsigned               address;
        logic [core_pkg::XLEN-1:0] data;
    } expected_csr_t;

    uvm_analysis_imp #(txn, scoreboard) item_export;

    bit            thrd_initialized[NUM_HW_THRDS];
    expected_rf_t  expected_rf     [NUM_HW_THRDS][$];
    expected_csr_t expected_csr    [NUM_HW_THRDS][$];

    bit iss_memory_writes[NUM_HW_THRDS][string];
    bit rtl_memory_writes[NUM_HW_THRDS][string];

    int unsigned commit_count;
    int unsigned check_count;
    int unsigned mismatch_count;
    string       image_path;

    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        item_export = new("item_export", this);
        foreach (thrd_initialized[i]) thrd_initialized[i] = 0;

        if (!$value$plusargs("ISA_BIN=%s", image_path))
            `uvm_fatal("ISA_SCB", "Missing +ISA_BIN=<flat program image>")
    endfunction

    function automatic string memory_key(
        logic [core_pkg::XLEN-1:0] address,
        logic [core_pkg::XLEN-1:0] mask,
        logic [core_pkg::XLEN-1:0] data
    );
        return $sformatf("%016h:%016h:%016h", address, mask, data & mask);
    endfunction

    function void record_iss_memory(int unsigned thread_id,
                                    arch_commit_trace_t trace);
        string key = memory_key(trace.mem_req_addr,
                                trace.mem_req_wmask,
                                trace.mem_req_wdata);
        iss_memory_writes[thread_id][key] = 1'b1;
    endfunction

    function void record_rtl_memory(mem_txn transaction);
        string key = memory_key(transaction.waddr,
                                transaction.wmask,
                                transaction.wdata);
        rtl_memory_writes[transaction.thrd_id][key] = 1'b1;
    endfunction

    function void process_commit(pc_txn transaction);
        arch_commit_trace_t trace = '{default: 0};

        commit_count++;
        if (!thrd_initialized[transaction.thrd_id]) begin
            if (iss_dpi_init(transaction.thrd_id, image_path) != 0)
                `uvm_fatal("ISA_SCB", $sformatf(
                    "Failed to initialize ISS thread %0d",
                    transaction.thrd_id))
            if (iss_set_pc(transaction.thrd_id, transaction.pc) != 0)
                `uvm_fatal("ISA_SCB", $sformatf(
                    "Failed to set ISS PC for thread %0d",
                    transaction.thrd_id))
            thrd_initialized[transaction.thrd_id] = 1;
        end
        iss_step(transaction.thrd_id, trace);
        if (!trace.commit_valid) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "ISS rejected RTL commit at thread %0d PC 0x%h",
                transaction.thrd_id, transaction.pc))
        end else if (trace.commit_pc != transaction.pc) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "PC mismatch on thread %0d: ISS=0x%h RTL=0x%h",
                transaction.thrd_id, trace.commit_pc, transaction.pc))
        end

        if (trace.rf_we) begin
            expected_rf_t expected;
            expected.pc = trace.rf_pc;
            expected.address = trace.rf_we_addr;
            expected.data = trace.rf_we_data;
            expected_rf[transaction.thrd_id].push_back(expected);
        end
        if (trace.csr_we) begin
            expected_csr_t expected;
            expected.pc = trace.csr_pc;
            expected.address = trace.csr_we_addr;
            expected.data = trace.csr_we_data;
            expected_csr[transaction.thrd_id].push_back(expected);
        end
        if (trace.mem_req_we)
            record_iss_memory(transaction.thrd_id, trace);
    endfunction

    function void process_rf(rf_txn transaction);
        expected_rf_t expected;
        check_count++;
        if (expected_rf[transaction.thrd_id].size() == 0) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "Unexpected GPR update on thread %0d at PC 0x%h: x%0d=0x%h",
                transaction.thrd_id, transaction.pc,
                transaction.waddr, transaction.wdata))
            return;
        end

        expected = expected_rf[transaction.thrd_id].pop_front();
        if (expected.pc != transaction.pc ||
            expected.address != transaction.waddr ||
            expected.data != transaction.wdata) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "GPR order/value mismatch on thread %0d: ISS(PC=0x%h x%0d=0x%h) RTL(PC=0x%h x%0d=0x%h)",
                transaction.thrd_id, expected.pc, expected.address, expected.data,
                transaction.pc, transaction.waddr, transaction.wdata))
        end
    endfunction

    function void process_csr(csr_txn transaction);
        expected_csr_t expected;
        logic [11:0] safe_address;
        check_count++;
        if (expected_csr[transaction.thrd_id].size() == 0) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "Unexpected CSR update on thread %0d at PC 0x%h: CSR[%0h]=0x%h",
                transaction.thrd_id, transaction.pc,
                transaction.waddr, transaction.wdata))
            return;
        end

        expected = expected_csr[transaction.thrd_id].pop_front();
        safe_address = expected.address[11:0];
        if (expected.pc != transaction.pc ||
            core_pkg::csr_addr_decode(safe_address) != transaction.waddr ||
            expected.data != transaction.wdata) begin
            mismatch_count++;
            `uvm_error("ISA_SCB", $sformatf(
                "CSR order/value mismatch on thread %0d: ISS(PC=0x%h CSR[0x%03h]=0x%h) RTL(PC=0x%h slot[%0h]=0x%h)",
                transaction.thrd_id, expected.pc, safe_address, expected.data,
                transaction.pc, transaction.waddr, transaction.wdata))
        end
    endfunction

    virtual function void write(txn transaction);
        pc_txn pc_transaction;
        rf_txn rf_transaction;
        csr_txn csr_transaction;
        mem_txn mem_transaction;

        `uvm_info("CORE_ARCH_COMMIT_SCB",
            $sformatf("Received commit transaction: %s", transaction.convert2string()),
            UVM_DEBUG)

        if ($cast(pc_transaction, transaction))
            process_commit(pc_transaction);
        else if ($cast(rf_transaction, transaction))
            process_rf(rf_transaction);
        else if ($cast(csr_transaction, transaction))
            process_csr(csr_transaction);
        else if ($cast(mem_transaction, transaction))
            record_rtl_memory(mem_transaction);
    endfunction

    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        foreach (expected_rf[thread_id]) begin
            while (expected_rf[thread_id].size() != 0) begin
                expected_rf_t expected = expected_rf[thread_id].pop_front();
                mismatch_count++;
                `uvm_error("ISA_SCB", $sformatf(
                    "Missing GPR update on thread %0d: PC=0x%h x%0d=0x%h",
                    thread_id, expected.pc, expected.address, expected.data))
            end
        end
        foreach (expected_csr[thread_id]) begin
            while (expected_csr[thread_id].size() != 0) begin
                expected_csr_t expected = expected_csr[thread_id].pop_front();
                mismatch_count++;
                `uvm_error("ISA_SCB", $sformatf(
                    "Missing CSR update on thread %0d: PC=0x%h CSR[0x%03h]=0x%h",
                    thread_id, expected.pc, expected.address[11:0], expected.data))
            end
        end

        foreach (iss_memory_writes[thread_id, key]) begin
            check_count++;
            if (!rtl_memory_writes[thread_id].exists(key)) begin
                mismatch_count++;
                `uvm_error("ISA_SCB", $sformatf(
                    "Missing RTL memory write on thread %0d: %s",
                    thread_id, key))
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        if (mismatch_count == 0)
            `uvm_info("ISA_SCB", $sformatf(
                "PASS: %0d committed instructions, %0d architectural values checked",
                commit_count, check_count), UVM_NONE)
        else
            `uvm_error("ISA_SCB", $sformatf(
                "FAIL: %0d mismatches across %0d committed instructions",
                mismatch_count, commit_count))
    endfunction

    function void final_phase(uvm_phase phase);
        super.final_phase(phase);
        iss_finish();
    endfunction
endclass: scoreboard
