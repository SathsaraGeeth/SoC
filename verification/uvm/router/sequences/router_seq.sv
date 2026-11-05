/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_seq extends uvm_sequence #(router_txn);
    `uvm_object_utils(router_seq)

    function new(string name = "router_seq");
        super.new(name);
    endfunction

    function automatic bit [63:0] address_for_direction(int direction);
        case (direction)
            0: return 64'hf000_0000_0000_0040;
            1: return 64'h0100_0000_0000_0080;
            2: return 64'h1000_0000_0000_00c0;
            3: return 64'h0f00_0000_0000_0100;
            default: return soc_pkg::UART_BASE_ADDR;
        endcase
    endfunction

    task automatic send_transaction(
        router_kind_e requested_kind,
        int requested_direction,
        bit [1:0] requested_priv,
        bit use_all_sources = 1'b0
    );
        router_txn txn;

        txn = router_txn::type_id::create("txn");
        start_item(txn);
        assert (txn.randomize() with {
            kind == requested_kind;
            direction == requested_direction;
            priv == requested_priv;
            all_sources == use_all_sources;
        }) else `uvm_error("ROUTER_SEQ", "Randomization failed")
        txn.addr = address_for_direction(requested_direction);
        if (requested_direction == 4)
            txn.addr = soc_pkg::UART_BASE_ADDR + 64'h08;
        txn.page_msg[3:0] = memory_pkg::PAGE_MSG_TLB_UPDATE;
        finish_item(txn);
    endtask: send_transaction

    virtual task body();
        int direction;

        for (direction = 0; direction < 4; direction++) begin
            send_transaction(ROUTER_INSTR, direction, isa_pkg::PRIV_MODE_M);
            send_transaction(ROUTER_DATA, direction, isa_pkg::PRIV_MODE_M);
        end

        send_transaction(ROUTER_INSTR, 1, isa_pkg::PRIV_MODE_U);
        send_transaction(ROUTER_DATA, 1, isa_pkg::PRIV_MODE_U);
        send_transaction(ROUTER_DATA, 4, isa_pkg::PRIV_MODE_M);

        repeat (4)
            send_transaction(ROUTER_PAGE_OUT, 1, isa_pkg::PRIV_MODE_M);
        for (direction = 0; direction < 4; direction++) begin
            send_transaction(ROUTER_PAGE_INSTR, direction, isa_pkg::PRIV_MODE_M);
            send_transaction(ROUTER_PAGE_DATA, direction, isa_pkg::PRIV_MODE_M);
        end
        send_transaction(ROUTER_PAGE_INSTR, 3, isa_pkg::PRIV_MODE_M, 1'b1);
        send_transaction(ROUTER_PAGE_DATA, 3, isa_pkg::PRIV_MODE_M, 1'b1);

        repeat (30) begin
            router_txn txn;
            txn = router_txn::type_id::create("random_txn");
            start_item(txn);
            assert (txn.randomize() with {
                txn.kind inside {ROUTER_INSTR, ROUTER_DATA,
                                 ROUTER_PAGE_OUT, ROUTER_PAGE_INSTR,
                                 ROUTER_PAGE_DATA};
                if (txn.kind inside {ROUTER_INSTR, ROUTER_DATA})
                    txn.direction inside {[0:4]};
                else
                    txn.direction inside {[0:3]};
                if (txn.direction == 4) {
                    txn.kind == ROUTER_DATA;
                    txn.priv == isa_pkg::PRIV_MODE_M;
                }
                txn.all_sources == 1'b0;
            }) else `uvm_error("ROUTER_SEQ", "Randomization failed")
            txn.addr = address_for_direction(txn.direction);
            if (txn.priv == isa_pkg::PRIV_MODE_U)
                txn.direction = 1;
            txn.page_msg[3:0] = memory_pkg::PAGE_MSG_TLB_UPDATE;
            finish_item(txn);
        end
    endtask: body
endclass: router_seq
