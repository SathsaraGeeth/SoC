/*
SPDX-License-Identifier: Apache-2.0

Copyright 2026 Geeth Sathsara

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import uvm_pkg::*;
import core_pkg::*;
`include "uvm_macros.svh"

class decoder_txn extends uvm_sequence_item;
    rand bit [3:0]          case_id;
    rand bit [isa_pkg::REG_BITS-1:0] rd;
    rand bit [isa_pkg::REG_BITS-1:0] rs1;
    rand bit [isa_pkg::REG_BITS-1:0] rs2;
    rand bit [11:0]         imm12;
    bit [isa_pkg::INST_W-1:0] instr;
    decoded_instr_t         decoded;

    constraint c_case {
        case_id inside {[0:13]};
        if (case_id == 12)
            rs1 != '0;
    }

    `uvm_object_utils_begin(decoder_txn)
        `uvm_field_int(case_id, UVM_ALL_ON)
        `uvm_field_int(rd, UVM_ALL_ON)
        `uvm_field_int(rs1, UVM_ALL_ON)
        `uvm_field_int(rs2, UVM_ALL_ON)
        `uvm_field_int(imm12, UVM_ALL_ON)
        `uvm_field_int(instr, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "decoder_txn");
        super.new(name);
    endfunction

    function void post_randomize();
        bit [6:0] opcode;
        bit [2:0] funct3;
        bit [6:0] funct7;

        opcode = 7'b0110011;
        funct3 = 3'b000;
        funct7 = 7'b0000000;
        unique case (case_id)
            0: begin opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0000000; end
            1: begin opcode = 7'b0110011; funct3 = 3'b000; funct7 = 7'b0100000; end
            2: begin opcode = 7'b0110011; funct3 = 3'b111; funct7 = 7'b0000000; end
            3: begin opcode = 7'b0010011; funct3 = 3'b000; funct7 = imm12[11:5]; end
            4: begin opcode = 7'b0000011; funct3 = 3'b010; funct7 = imm12[11:5]; end
            5: begin opcode = 7'b0000011; funct3 = 3'b011; funct7 = imm12[11:5]; end
            6: begin opcode = 7'b0100011; funct3 = 3'b010; funct7 = imm12[11:5]; end
            7: begin opcode = 7'b1100011; funct3 = 3'b000; funct7 = {imm12[11], imm12[9:4]}; end
            8: begin opcode = 7'b1101111; funct3 = imm12[3:1]; funct7 = imm12[10:4]; end
            9: begin opcode = 7'b1100111; funct3 = 3'b000; funct7 = imm12[11:5]; end
            10: begin opcode = 7'b0110111; funct3 = imm12[3:1]; funct7 = imm12[10:4]; end
            11: begin opcode = 7'b0010111; funct3 = imm12[3:1]; funct7 = imm12[10:4]; end
            12: begin opcode = 7'b1110011; funct3 = 3'b001; funct7 = imm12[11:5]; end
            default: begin opcode = 7'b0000000; funct3 = 3'b000; funct7 = 7'b0000000; end
        endcase

        unique case (case_id)
            6:
                instr = {imm12[11:5], rs2, rs1, funct3, imm12[4:0], opcode};
            7:
                instr = {imm12[11], imm12[9:4], rs2, rs1, funct3,
                         imm12[3:0], imm12[10], opcode};
            8:
                instr = {imm12[11], imm12[9:0], imm12[10], imm12[3:1],
                         rd, opcode};
            10, 11:
                instr = {imm12, rs1, funct3, rd, opcode};
            12:
                instr = {12'h300, rs1, funct3, rd, opcode};
            default:
                instr = {funct7, rs2, rs1, funct3, rd, opcode};
        endcase
    endfunction: post_randomize
endclass: decoder_txn
