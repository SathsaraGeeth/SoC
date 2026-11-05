/*
 * Comments:
 * 1. This provides an ideal memory model for ISA verification
 *    not depending on the actual memory implementation in the rtl/memory/
 * 2. Provides the smallest possible expectations from the rtl/core/
 */

`timescale 1ns/1ps
import core_pkg::*;

module test_memory (
    input  logic                            i_clk,
    input  logic                            i_rst_n,
    input  logic [VIR_ADDR_W-1:0]           i_req_instr_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_req_instr_thrd_id,
    input  logic                            i_req_instr_valid, 
    output logic                            o_req_instr_ready,
    output logic [core_pkg::XLEN-1:0]       o_resp_instr,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_resp_instr_thrd_id,
    output logic                            o_resp_instr_valid, 
    input  logic                            i_resp_instr_ready,
    input  logic [VIR_ADDR_W-1:0]           i_req_data_addr,
    input  logic [$clog2(NUM_HW_THRDS)-1:0] i_req_data_thrd_id,
    input  logic                            i_req_data_rw, 
    input  logic                            i_req_data_lr,
    input  logic                            i_req_data_sc,
    input  logic [core_pkg::XLEN/8-1:0]     i_req_data_wstrb,
    input  logic [core_pkg::XLEN-1:0]       i_req_data_wdata,
    input  logic                            i_req_data_valid, 
    output logic                            o_req_data_ready,
    output logic [core_pkg::XLEN-1:0]       o_resp_data_rdata,
    output logic                            o_resp_data_sc_ok,
    output logic [$clog2(NUM_HW_THRDS)-1:0] o_resp_data_thrd_id,
    output logic                            o_resp_data_valid, 
    input  logic                            i_resp_data_ready
);
    localparam int DATA_BYTES = core_pkg::XLEN / 8;
    localparam int BYTE_OFFSET_W = $clog2(DATA_BYTES);

    typedef struct {
        logic [core_pkg::XLEN-1:0]       value;
        logic                            locked;
        logic [$clog2(NUM_HW_THRDS)-1:0] owner;
    } memory_word_t;

    memory_word_t mem [longint unsigned];
    string        image_path;

    function automatic logic [VIR_ADDR_W-1:0] aligned_address(
                 input logic [VIR_ADDR_W-1:0] addr);
        return {addr[VIR_ADDR_W-1:BYTE_OFFSET_W], {BYTE_OFFSET_W{1'b0}}};
    endfunction

    function automatic logic [core_pkg::XLEN-1:0] read_word(
                 input logic [VIR_ADDR_W-1:0] addr);

        logic [VIR_ADDR_W-1:0] base = aligned_address(addr);
        return mem.exists(longint'(base)) ? mem[longint'(base)].value : '0;

    endfunction

    task automatic release_owner(
        input logic [$clog2(NUM_HW_THRDS)-1:0] owner);
        foreach (mem[address])
            if (mem[address].locked && mem[address].owner == owner)
                mem[address].locked = 1'b0;
    endtask

    initial begin
        int                    fd;
        int                    ch;
        automatic int unsigned index;

        index = 0;

        /*
         * Loads the porgram from the file to memory model
         * Service reads
         * Writes the non zero ones to save time
         * usage: ./sim +ISA_BIN=test.bin
         */

        if (!$value$plusargs("ISA_BIN=%s", image_path))
            $fatal(1, "Missing +ISA_BIN=<flat program image>");

        fd = $fopen(image_path, "rb");

        if (fd == 0) 
            $fatal(1, "Cannot open ISA image '%s'", image_path);

        while (!$feof(fd)) begin
            ch = $fgetc(fd);
            if (ch >= 0) begin
                automatic longint unsigned address =
                    longint'(aligned_address(VIR_ADDR_W'(index)));
                automatic int lane = index % DATA_BYTES;
                automatic memory_word_t word = mem.exists(address) ?
                    mem[address] : '{default: '0};

                word.value[lane*8 +: 8] = byte'(ch);
                mem[address] = word;
                index++;
            end
        end

        $fclose(fd);

        $display("ISA memory: loaded %0d bytes from %s", index, image_path);

        forever begin
            @(posedge i_clk);
            if (!i_rst_n) begin
                o_resp_instr_valid <= 1'b0;
                o_resp_data_valid  <= 1'b0;
                o_resp_data_sc_ok  <= 1'b0;
                foreach (mem[address])
                    mem[address].locked = 1'b0;
            end else begin
                if (i_resp_instr_ready) 
                    o_resp_instr_valid   <= 1'b0;
                if (i_req_instr_valid && o_req_instr_ready) begin
                    o_resp_instr         <= read_word(i_req_instr_addr);
                    o_resp_instr_thrd_id <= i_req_instr_thrd_id;
                    o_resp_instr_valid   <= 1'b1;
                end
                if (i_resp_data_ready) 
                    o_resp_data_valid   <= 1'b0;
                if (i_req_data_valid && o_req_data_ready) begin
                    automatic logic [VIR_ADDR_W-1:0] request_addr;
                    automatic logic                 sc_success;
                    automatic longint unsigned      word_address;
                    automatic memory_word_t         word;

                    request_addr = aligned_address(i_req_data_addr);
                    word_address = longint'(request_addr);
                    word = mem.exists(word_address) ?
                           mem[word_address] : '{default: '0};
                    sc_success = i_req_data_sc &&
                                 word.locked &&
                                 word.owner == i_req_data_thrd_id;

                    o_resp_data_rdata   <= read_word(i_req_data_addr);
                    o_resp_data_thrd_id <= i_req_data_thrd_id;
                    o_resp_data_sc_ok   <= sc_success;
                    o_resp_data_valid   <= 1'b1;

                    if (i_req_data_rw && (!i_req_data_sc || sc_success)) begin
                        for (int i = 0; i < DATA_BYTES; i++)
                            if (i_req_data_wstrb[i])
                                word.value[i*8 +: 8] =
                                    i_req_data_wdata[i*8 +: 8];
                        word.locked = 1'b0;
                        mem[word_address] = word;
                    end

                    if (i_req_data_lr) begin
                        release_owner(i_req_data_thrd_id);
                        word.owner = i_req_data_thrd_id;
                        word.locked = 1'b1;
                        mem[word_address] = word;
                    end

                    if (i_req_data_sc)
                        release_owner(i_req_data_thrd_id);
                end
            end
        end
    end

    assign o_req_instr_ready = !o_resp_instr_valid || i_resp_instr_ready;
    assign o_req_data_ready  = !o_resp_data_valid  || i_resp_data_ready;

endmodule: test_memory
