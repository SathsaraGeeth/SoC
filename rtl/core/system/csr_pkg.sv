/*
 * csr_pkg.sv
 * 
 * Copyright (C) 2026 Sathsara Geeth
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

package csr_pkg;

    localparam int unsigned NUM_CSR_SLOTS = 24;
    localparam int unsigned CSR_SLOT_W    = $clog2(NUM_CSR_SLOTS);

    typedef enum logic [CSR_SLOT_W-1:0] {
        CSR_SLOT_MSTATUS,
        CSR_SLOT_MIE,
        CSR_SLOT_MIP,
        CSR_SLOT_MEPC,
        CSR_SLOT_MCAUSE,
        CSR_SLOT_MTVEC,
        CSR_SLOT_MSCRATCH,
        CSR_SLOT_FCSR,
        CSR_SLOT_THREAD_ID,
        CSR_SLOT_VIRTUAL_THRD_ID,
        CSR_SLOT_SATP,
        CSR_SLOT_PAGE_MSG_ARG0,
        CSR_SLOT_PAGE_MSG_ARG1,
        CSR_SLOT_PAGE_MSG_CMD,
        CSR_SLOT_SSTATUS,
        CSR_SLOT_SIE,
        CSR_SLOT_SIP,
        CSR_SLOT_SEPC,
        CSR_SLOT_SCAUSE,
        CSR_SLOT_STVAL,
        CSR_SLOT_STVEC,
        CSR_SLOT_SSCRATCH,
        CSR_SLOT_MEDELEG,
        CSR_SLOT_MIDELEG
    } csr_slot_e;

    typedef struct packed {
        logic      valid;
        csr_slot_e slot;
    } csr_slot_decode_t;

    localparam logic [11:0] CSR_ADDR_MSTATUS         = 12'h300;
    localparam logic [11:0] CSR_ADDR_MIE             = 12'h304;
    localparam logic [11:0] CSR_ADDR_MIP             = 12'h344;
    localparam logic [11:0] CSR_ADDR_MEPC            = 12'h341;
    localparam logic [11:0] CSR_ADDR_MCAUSE          = 12'h342;
    localparam logic [11:0] CSR_ADDR_MTVEC           = 12'h305;
    localparam logic [11:0] CSR_ADDR_MSCRATCH        = 12'h340;
    localparam logic [11:0] CSR_ADDR_FCSR            = 12'h003;
    localparam logic [11:0] CSR_ADDR_THREAD_ID       = 12'h7C1;
    localparam logic [11:0] CSR_ADDR_VIRTUAL_THRD_ID = 12'h7C3;
    localparam logic [11:0] CSR_ADDR_SATP            = 12'h180;
    localparam logic [11:0] CSR_ADDR_PAGE_MSG_ARG0   = 12'h7C4;
    localparam logic [11:0] CSR_ADDR_PAGE_MSG_ARG1   = 12'h7C5;
    localparam logic [11:0] CSR_ADDR_PAGE_MSG_CMD    = 12'h7C6;
    localparam logic [11:0] CSR_ADDR_SSTATUS         = 12'h100;
    localparam logic [11:0] CSR_ADDR_SIE             = 12'h104;
    localparam logic [11:0] CSR_ADDR_SIP             = 12'h144;
    localparam logic [11:0] CSR_ADDR_SEPC            = 12'h141;
    localparam logic [11:0] CSR_ADDR_SCAUSE          = 12'h142;
    localparam logic [11:0] CSR_ADDR_STVAL           = 12'h143;
    localparam logic [11:0] CSR_ADDR_STVEC           = 12'h105;
    localparam logic [11:0] CSR_ADDR_SSCRATCH        = 12'h140;
    localparam logic [11:0] CSR_ADDR_MEDELEG         = 12'h302;
    localparam logic [11:0] CSR_ADDR_MIDELEG         = 12'h303;


    function automatic csr_slot_decode_t csr_addr_to_slot (
        input logic [11:0] i_csr_addr
    );
        csr_slot_decode_t result;

        result.valid = 1'b1;
        result.slot  = CSR_SLOT_MSTATUS;

        unique case (i_csr_addr)
            CSR_ADDR_MSTATUS:         result.slot = CSR_SLOT_MSTATUS;
            CSR_ADDR_MIE:             result.slot = CSR_SLOT_MIE;
            CSR_ADDR_MIP:             result.slot = CSR_SLOT_MIP;
            CSR_ADDR_MEPC:            result.slot = CSR_SLOT_MEPC;
            CSR_ADDR_MCAUSE:          result.slot = CSR_SLOT_MCAUSE;
            CSR_ADDR_MTVEC:           result.slot = CSR_SLOT_MTVEC;
            CSR_ADDR_MSCRATCH:        result.slot = CSR_SLOT_MSCRATCH;
            CSR_ADDR_FCSR:            result.slot = CSR_SLOT_FCSR;
            CSR_ADDR_THREAD_ID:       result.slot = CSR_SLOT_THREAD_ID;
            CSR_ADDR_VIRTUAL_THRD_ID: result.slot = CSR_SLOT_VIRTUAL_THRD_ID;
            CSR_ADDR_SATP:            result.slot = CSR_SLOT_SATP;
            CSR_ADDR_PAGE_MSG_ARG0:   result.slot = CSR_SLOT_PAGE_MSG_ARG0;
            CSR_ADDR_PAGE_MSG_ARG1:   result.slot = CSR_SLOT_PAGE_MSG_ARG1;
            CSR_ADDR_PAGE_MSG_CMD:    result.slot = CSR_SLOT_PAGE_MSG_CMD;
            CSR_ADDR_SSTATUS:         result.slot = CSR_SLOT_SSTATUS;
            CSR_ADDR_SIE:             result.slot = CSR_SLOT_SIE;
            CSR_ADDR_SIP:             result.slot = CSR_SLOT_SIP;
            CSR_ADDR_SEPC:            result.slot = CSR_SLOT_SEPC;
            CSR_ADDR_SCAUSE:          result.slot = CSR_SLOT_SCAUSE;
            CSR_ADDR_STVAL:           result.slot = CSR_SLOT_STVAL;
            CSR_ADDR_STVEC:           result.slot = CSR_SLOT_STVEC;
            CSR_ADDR_SSCRATCH:        result.slot = CSR_SLOT_SSCRATCH;
            CSR_ADDR_MEDELEG:         result.slot = CSR_SLOT_MEDELEG;
            CSR_ADDR_MIDELEG:         result.slot = CSR_SLOT_MIDELEG;

            default: begin
                result.valid = 1'b0;
                result.slot  = CSR_SLOT_MSTATUS;
            end
        endcase

        return result;
    endfunction


    function automatic logic [11:0] csr_slot_to_addr (
        input csr_slot_e i_csr_slot
    );
        unique case (i_csr_slot)
            CSR_SLOT_MSTATUS:         return CSR_ADDR_MSTATUS;
            CSR_SLOT_MIE:             return CSR_ADDR_MIE;
            CSR_SLOT_MIP:             return CSR_ADDR_MIP;
            CSR_SLOT_MEPC:            return CSR_ADDR_MEPC;
            CSR_SLOT_MCAUSE:          return CSR_ADDR_MCAUSE;
            CSR_SLOT_MTVEC:           return CSR_ADDR_MTVEC;
            CSR_SLOT_MSCRATCH:        return CSR_ADDR_MSCRATCH;
            CSR_SLOT_FCSR:            return CSR_ADDR_FCSR;
            CSR_SLOT_THREAD_ID:       return CSR_ADDR_THREAD_ID;
            CSR_SLOT_VIRTUAL_THRD_ID: return CSR_ADDR_VIRTUAL_THRD_ID;
            CSR_SLOT_SATP:            return CSR_ADDR_SATP;
            CSR_SLOT_PAGE_MSG_ARG0:   return CSR_ADDR_PAGE_MSG_ARG0;
            CSR_SLOT_PAGE_MSG_ARG1:   return CSR_ADDR_PAGE_MSG_ARG1;
            CSR_SLOT_PAGE_MSG_CMD:    return CSR_ADDR_PAGE_MSG_CMD;
            CSR_SLOT_SSTATUS:         return CSR_ADDR_SSTATUS;
            CSR_SLOT_SIE:             return CSR_ADDR_SIE;
            CSR_SLOT_SIP:             return CSR_ADDR_SIP;
            CSR_SLOT_SEPC:            return CSR_ADDR_SEPC;
            CSR_SLOT_SCAUSE:          return CSR_ADDR_SCAUSE;
            CSR_SLOT_STVAL:           return CSR_ADDR_STVAL;
            CSR_SLOT_STVEC:           return CSR_ADDR_STVEC;
            CSR_SLOT_SSCRATCH:        return CSR_ADDR_SSCRATCH;
            CSR_SLOT_MEDELEG:         return CSR_ADDR_MEDELEG;
            CSR_SLOT_MIDELEG:         return CSR_ADDR_MIDELEG;
            default:                  return 12'h000;
        endcase
    endfunction

    function automatic logic [CSR_MEM_ADDR_W-1:0] flatten_csr_addr (
        input logic [$clog2(NUM_HW_THRDS)-1:0] i_thrd_id,
        input csr_slot_e                       i_csr_slot
    );
        return CSR_MEM_ADDR_W'(unsigned'(i_thrd_id) * NUM_CSR_SLOTS + unsigned'(i_csr_slot));
    endfunction

endpackage : csr_pkg
