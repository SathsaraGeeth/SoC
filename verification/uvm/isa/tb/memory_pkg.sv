/*
 * Comments:
 * 1. This provides an ideal memory model for ISA verification
 *    not depending on the actual memory implementation in the rtl/memory/
 * 2. Provides the smallest possible expectations from the rtl/core/
 */

`timescale 1ns/1ps
 
package memory_pkg;
    import isa_pkg::PRIV_MODE_W;

    parameter int PAGE_BYTES_W          = 12;
    parameter int PAGE_SIZE             = 1 << PAGE_BYTES_W;
    parameter int PAGE_MSG_W            = 136;
    parameter int PAGE_MSG_TYPE_W       = 4;
    parameter int PAGE_MSG_DATA_W       = PAGE_MSG_W - PAGE_MSG_TYPE_W;
    parameter int VPN_W                 = isa_pkg::XLEN - PAGE_BYTES_W;
    parameter int THRD_W                = $clog2(core_pkg::NUM_HW_THRDS);
    parameter int PPN_W                 = 10;
    parameter int VTID_W                = isa_pkg::XLEN;
    parameter int USER_ACC_W            = 1;
    parameter int WRITE_ACC_W           = 1;
    parameter int TLB_UPDATE_VTID_ARG_W = PAGE_BYTES_W - USER_ACC_W - WRITE_ACC_W;
    parameter int AXI_ADDR_W            = isa_pkg::XLEN;

    typedef enum logic [PAGE_MSG_TYPE_W-1:0] {
        PAGE_MSG_FAULT       = 4'd1,
        PAGE_MSG_TLB_UPDATE  = 4'd2,
        PAGE_MSG_PAGE_LOAD   = 4'd3,
        PAGE_MSG_PAGE_EVICT  = 4'd4,
        PAGE_MSG_VTID_UPDATE = 4'd5
    } page_msg_type_e;

    typedef struct packed {
        logic [PAGE_MSG_DATA_W-1:0] padding;
        page_msg_type_e             msg_type;
    } generic_page_msg_t;

    typedef struct packed {
        logic [PAGE_MSG_DATA_W-VPN_W-THRD_W-1:0] padding;
        logic [THRD_W-1:0]                       thrd_id;
        logic [VPN_W-1:0]                        vpn;
        page_msg_type_e                          msg_type;
    } page_fault_msg_t;

    typedef struct packed {
        logic [PAGE_MSG_DATA_W-VPN_W-PPN_W-VTID_W-USER_ACC_W-WRITE_ACC_W-1:0] padding;
        logic                                                                 user_acc;
        logic                                                                 writable;
        logic [VTID_W-1:0]                                                    vtid;
        logic [PPN_W-1:0]                                                     ppn;
        logic [VPN_W-1:0]                                                     vpn;
        page_msg_type_e                                                       msg_type;
    } tlb_update_msg_t;

    typedef struct packed {
        logic [PAGE_MSG_DATA_W-AXI_ADDR_W-PPN_W-THRD_W-1:0] padding;
        logic [THRD_W-1:0]                                  thrd_id;
        logic [AXI_ADDR_W-1:0]                              axi_addr;
        logic [PPN_W-1:0]                                   ppn;
        page_msg_type_e                                     msg_type;
    } page_transfer_msg_t;

    typedef struct packed {
        logic [PAGE_MSG_DATA_W-VTID_W-THRD_W-1:0] padding;
        logic [VTID_W-1:0]                        vtid;
        logic [THRD_W-1:0]                        thrd_id;
        page_msg_type_e                           msg_type;
    } vtid_update_msg_t;

endpackage: memory_pkg
