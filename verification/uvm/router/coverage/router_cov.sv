/* SPDX-License-Identifier: Apache-2.0 */

import uvm_pkg::*;
`include "uvm_macros.svh"

class router_cov extends uvm_subscriber #(router_txn);
    `uvm_component_utils(router_cov)

    router_kind_e kind;
    bit [2:0] direction;
    bit [1:0] priv;
    bit backpressured;
    bit all_sources;

    covergroup router_cg;
        cp_kind: coverpoint kind;
        cp_direction: coverpoint direction {
            bins north = {0};
            bins east = {1};
            bins south = {2};
            bins west = {3};
            bins mmio = {4};
        }
        cp_priv: coverpoint priv {
            bins user = {isa_pkg::PRIV_MODE_U};
            bins machine = {isa_pkg::PRIV_MODE_M};
        }
        cp_backpressure: coverpoint backpressured;
        cp_priority: coverpoint all_sources;
        cross cp_kind, cp_direction;
    endgroup

    function new(string name = "router_cov", uvm_component parent = null);
        super.new(name, parent);
        router_cg = new();
    endfunction

    function void write(router_txn txn);
        kind = txn.kind;
        direction = txn.direction;
        priv = txn.priv;
        backpressured = txn.stall_cycles != 0;
        all_sources = txn.all_sources;
        router_cg.sample();
    endfunction
endclass: router_cov
