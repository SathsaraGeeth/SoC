`timescale 1ns/1ps
`default_nettype none
module frontend_perf_tb;
    import core_pkg::*;
    import memory_pkg::*;
    localparam int HW_THREADS = 32;
    localparam int RUN_CYCLES = 20000;
    logic clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    logic irq_timer[HW_THREADS], irq_wake[HW_THREADS];
    logic backend_sleep[HW_THREADS], update_priv_mode[HW_THREADS];
    logic [PRIV_MODE_W-1:0] priv_mode[HW_THREADS];
    logic backend_fence_i[HW_THREADS], backend_wake[HW_THREADS];
    logic req_ready, req_valid, resp_ready, resp_valid;
    mem_req_t req; mem_resp_t resp;
    logic page_valid, page_ready; mem_page_resp_t page_resp;
    logic decoded_valid[HW_THREADS], decoded_ready[HW_THREADS];
    frontend_pkg::decoded_instr_t decoded[HW_THREADS];
    logic redirect_valid[HW_THREADS]; logic [VIR_ADDR_W-1:0] redirect_pc[HW_THREADS];

    frontend dut(.*,
        .i_clk(clk), .i_rst_n(rst_n), .i_irq_timer(irq_timer), .i_irq_wake(irq_wake),
        .i_backend_sleep(backend_sleep), .i_backend_priv_update(update_priv_mode),
        .i_priv_mode(priv_mode), .i_backend_fence_i(backend_fence_i), .i_backend_wake(backend_wake),
        .i_req_instr_ready(req_ready), .o_req_instr_valid(req_valid), .o_req_instr(req),
        .o_resp_instr_ready(resp_ready), .i_resp_instr_valid(resp_valid), .i_resp_instr(resp),
        .i_resp_page_msg_instr_valid(page_valid), .o_resp_page_msg_instr_ready(page_ready),
        .i_resp_page_msg_instr(page_resp), .o_decoded_instr_valid(decoded_valid),
        .i_decoded_instr_ready(decoded_ready), .o_decoded_instr(decoded),
        .i_redirect_valid(redirect_valid), .i_redirect_pc(redirect_pc));

    integer active_threads = 1;
    integer cycle_count, req_cycles, req_accepts, resp_accepts, req_blocked, resp_blocked;
    integer valid_slots_sum, any_valid_cycles, all_valid_cycles, consumed_total;
    integer presented_hist[0:HW_THREADS];
    integer presented_cycles[HW_THREADS], consumed[HW_THREADS];
    integer refill_start[HW_THREADS], refill_sum[HW_THREADS], refill_max[HW_THREADS], refill_count[HW_THREADS];
    integer refill_hist[0:255];
    logic [$clog2(HW_THREADS)-1:0] backend_last, backend_thread;
    logic backend_found;
    logic [63:0] program_mem[0:4095];
    integer program_words;
    string program_hex;

    localparam int MEM_QUEUE_DEPTH = 64;
    logic [$clog2(HW_THREADS)-1:0] mem_thrd[MEM_QUEUE_DEPTH];
    logic [63:0] mem_data[MEM_QUEUE_DEPTH];
    integer mem_due[MEM_QUEUE_DEPTH];
    integer mem_rd_ptr, mem_wr_ptr, mem_count;

    logic feedback_pending[HW_THREADS];
    logic [VIR_ADDR_W-1:0] feedback_pc[HW_THREADS];
    integer feedback_due[HW_THREADS];

    function automatic logic [63:0] program_line(input logic [VIR_ADDR_W-1:0] addr);
        integer word_address;
        begin
            word_address = int'(addr >> 3);
            program_line = (word_address >= 0 && word_address < program_words) ?
                           program_mem[word_address] : 64'h00000013_00000013;
        end
    endfunction

    // The modeled backend has one global consume port. It selects at most one
    // presented instruction per cycle with round-robin fairness.
    always_comb begin
        backend_thread = '0;
        backend_found = 1'b0;
        for (int t=0;t<HW_THREADS;t++) decoded_ready[t] = 1'b0;
        for (int k=0;k<HW_THREADS;k++) begin
            automatic int t = (int'(backend_last)+1+k)%HW_THREADS;
            if (!backend_found && t < active_threads && decoded_valid[t]) begin
                backend_thread = $clog2(HW_THREADS)'(t);
                backend_found = 1'b1;
            end
        end
        if (backend_found) decoded_ready[backend_thread] = 1'b1;
    end

    initial begin
        if (!$value$plusargs("ACTIVE_THREADS=%d", active_threads)) active_threads = 1;
        if (!$value$plusargs("PROGRAM_HEX=%s", program_hex)) $fatal(1, "PROGRAM_HEX is required");
        if (!$value$plusargs("PROGRAM_WORDS=%d", program_words)) $fatal(1, "PROGRAM_WORDS is required");
        $readmemh(program_hex, program_mem);
        if (active_threads < 1 || active_threads > HW_THREADS) $fatal(1, "bad ACTIVE_THREADS");
        for (int t=0;t<HW_THREADS;t++) begin
            irq_timer[t]=0; irq_wake[t]=0; backend_sleep[t]=0; update_priv_mode[t]=0;
            priv_mode[t]=PRIV_MODE_M;
            backend_fence_i[t]=0; backend_wake[t]=0;
            redirect_valid[t]=0; redirect_pc[t]='0; refill_start[t]=-1;
            feedback_pending[t]=0; feedback_pc[t]='0; feedback_due[t]=0;
            presented_cycles[t]=0; consumed[t]=0; refill_sum[t]=0; refill_max[t]=0; refill_count[t]=0;
        end
        for (int n=0;n<=HW_THREADS;n++) presented_hist[n]=0;
        for (int n=0;n<=255;n++) refill_hist[n]=0;
        page_valid=0; page_resp='0;
        mem_rd_ptr=0; mem_wr_ptr=0; mem_count=0;
        cycle_count=0; req_cycles=0; req_accepts=0; resp_accepts=0; req_blocked=0; resp_blocked=0;
        valid_slots_sum=0; any_valid_cycles=0; all_valid_cycles=0; consumed_total=0;
        backend_last=HW_THREADS-1;
        repeat(5) @(posedge clk); rst_n <= 1;
        @(posedge clk);
        for (int t=0;t<active_threads;t++) begin redirect_valid[t] <= 1; redirect_pc[t] <= VIR_ADDR_W'(t*4096); end
        @(posedge clk); for (int t=0;t<active_threads;t++) redirect_valid[t] <= 0;
    end

    // Pipelined instruction memory. A request can be accepted every cycle and
    // receives an independently randomized 3-7 cycle service latency.
    assign req_ready = mem_count < MEM_QUEUE_DEPTH;
    assign resp_valid = mem_count != 0 && cycle_count >= mem_due[mem_rd_ptr];
    assign resp.thrd = mem_thrd[mem_rd_ptr];
    assign resp.sc_succ = 1'b0;
    assign resp.rdata = mem_data[mem_rd_ptr];

    always @(posedge clk) begin
        if (rst_n) begin
            int slots;
            slots = 0;
            cycle_count <= cycle_count + 1;
            if (req_valid) req_cycles <= req_cycles + 1;
            if (req_valid && !req_ready) req_blocked <= req_blocked + 1;
            if (resp_valid && !resp_ready) resp_blocked <= resp_blocked + 1;
            if (resp_valid && resp_ready) resp_accepts <= resp_accepts + 1;
            unique case ({req_valid && req_ready, resp_valid && resp_ready})
                2'b10: mem_count <= mem_count + 1;
                2'b01: mem_count <= mem_count - 1;
                default: ;
            endcase
            if (req_valid && req_ready) begin
                mem_thrd[mem_wr_ptr] <= req.thrd;
                mem_data[mem_wr_ptr] <= program_line(req.addr);
                mem_due[mem_wr_ptr] <= cycle_count + $urandom_range(7, 3);
                mem_wr_ptr <= (mem_wr_ptr + 1) % MEM_QUEUE_DEPTH;
                req_accepts <= req_accepts + 1;
            end
            if (resp_valid && resp_ready)
                mem_rd_ptr <= (mem_rd_ptr + 1) % MEM_QUEUE_DEPTH;

            for (int t=0;t<HW_THREADS;t++) begin
                redirect_valid[t] <= 1'b0;
                if (feedback_pending[t] && cycle_count >= feedback_due[t]) begin
                    redirect_valid[t] <= 1'b1;
                    redirect_pc[t] <= feedback_pc[t];
                    feedback_pending[t] <= 1'b0;
                end

                if (t < active_threads && decoded_valid[t]) begin
                    slots++; presented_cycles[t] <= presented_cycles[t] + 1;
                    if (refill_start[t] >= 0) begin
                        int latency;
                        latency = cycle_count-refill_start[t];
                        refill_sum[t] <= refill_sum[t]+latency; refill_count[t] <= refill_count[t]+1;
                        if (latency>refill_max[t]) refill_max[t] <= latency;
                        refill_hist[(latency>255)?255:latency] <= refill_hist[(latency>255)?255:latency]+1;
                        refill_start[t] <= -1;
                    end
                    if (decoded_ready[t]) begin
                        consumed[t] <= consumed[t]+1; consumed_total <= consumed_total+1; refill_start[t] <= cycle_count;
                        backend_last <= $clog2(HW_THREADS)'(t);
                        // Minimal control-flow feedback from the single-port
                        // backend. Conditional branches are modeled not taken;
                        // direct jumps use their decoded target. JALR cannot be
                        // resolved without a register file, so it is sequential.
                        if (decoded[t].fu == frontend_pkg::FU_BRANCH) begin
                            feedback_pending[t] <= 1'b1;
                            feedback_due[t] <= cycle_count + $urandom_range(9, 2);
                            unique case (decoded[t].fu_ctrl.branch.op)
                                frontend_pkg::BRANCH_JAL:
                                    feedback_pc[t] <= VIR_ADDR_W'(
                                        $signed(decoded[t].operands.pc_imm_rd.pc) +
                                        $signed(decoded[t].operands.pc_imm_rd.imm));
                                frontend_pkg::BRANCH_JALR:
                                    feedback_pc[t] <= VIR_ADDR_W'(
                                        decoded[t].operands.jalr.pc + 64'd4);
                                default:
                                    feedback_pc[t] <= VIR_ADDR_W'(
                                        decoded[t].operands.branch.pc + 64'd4);
                            endcase
                        end
                    end
                end
            end
            presented_hist[slots] <= presented_hist[slots]+1;
            valid_slots_sum <= valid_slots_sum+slots;
            if (slots != 0) any_valid_cycles <= any_valid_cycles+1;
            if (slots == active_threads) all_valid_cycles <= all_valid_cycles+1;

            if (cycle_count == RUN_CYCLES) begin
                $display("PERF_FRONTEND active=%0d cycles=%0d presented_slot_cycles=%0d consumed=%0d any_valid_cycles=%0d all_valid_cycles=%0d req_valid_cycles=%0d req_accepts=%0d responses=%0d req_blocked=%0d resp_blocked=%0d",
                    active_threads, cycle_count, valid_slots_sum, consumed_total, any_valid_cycles,
                    all_valid_cycles, req_cycles, req_accepts, resp_accepts, req_blocked, resp_blocked);
                for (int n=0;n<=active_threads;n++) if (presented_hist[n])
                    $display("PERF_PRESENT_HIST count=%0d cycles=%0d",n,presented_hist[n]);
                for (int n=0;n<=255;n++) if (refill_hist[n])
                    $display("PERF_REFILL_HIST latency=%0d count=%0d",n,refill_hist[n]);
                for (int t=0;t<active_threads;t++)
                    $display("PERF_THREAD id=%0d presented_cycles=%0d consumed=%0d refill_count=%0d refill_sum=%0d refill_max=%0d",
                        t,presented_cycles[t],consumed[t],refill_count[t],refill_sum[t],refill_max[t]);
                $finish;
            end
        end
    end
endmodule
`default_nettype wire
