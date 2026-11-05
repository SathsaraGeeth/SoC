`timescale 1ns/1ps
package memory_pkg;

import isa_pkg::*;

parameter int XLEN                  = core_pkg::XLEN;
parameter int VIR_ADDR_W            = topology_pkg::VIR_ADDR_W;
parameter int BANK_WORD_W           = XLEN;
parameter int NUM_CPU_RW_PORTS      = topology_pkg::CORES_PER_CLUSTER * 4 * 2; // 4-N,E,S,W, 2-I,D
parameter int SYS_RW_PORTS_PER_CORE = 3;
parameter int NUM_SYS_RW_PORTS      = topology_pkg::SYS_CORES_PER_CLUSTER * SYS_RW_PORTS_PER_CORE;
parameter int NUM_RW_PORTS          = NUM_CPU_RW_PORTS + NUM_SYS_RW_PORTS;
parameter int NUM_BANKS             = 2 * NUM_CPU_RW_PORTS;
parameter int PAGE_WORDS_W           = 9;
parameter int PAGE_BYTES_W          = PAGE_WORDS_W + $clog2(XLEN / 8);
parameter int PAGE_WORDS            = 1 << PAGE_WORDS_W;
parameter int PAGE_BYTES            = 1 << PAGE_BYTES_W;
parameter int PAGE_ADDR_W           = PAGE_BYTES_W;
parameter int NUM_PAGES_W            = 10;
parameter int NUM_PAGES             = 1 << NUM_PAGES_W;
parameter int PAGE_SIZE             = PAGE_BYTES; // bytes
parameter int BANK_DEPTH            = (NUM_PAGES * PAGE_BYTES * 8) / (NUM_BANKS * BANK_WORD_W); // words              
parameter int BANK_ADDR_W           = $clog2(BANK_DEPTH);
parameter int REQ_BUFF_DEPTH        = 8;
parameter int PORT_W                = BANK_WORD_W;
parameter int LINE_W                = NUM_BANKS * XLEN;
parameter int PAGE_MSG_W            = 136;
parameter int PAGE_MSG_TYPE_W       = 4;
parameter int PAGE_MSG_DATA_W       = PAGE_MSG_W - PAGE_MSG_TYPE_W;
parameter int VPN_W                 = VIR_ADDR_W - PAGE_ADDR_W;
parameter int THRD_W                = topology_pkg::THREAD_OFFSET_BITS;
parameter int PORT_IDX_W            = $clog2(NUM_RW_PORTS);
parameter int PPN_W                 = NUM_PAGES_W;
parameter int VTID_W                = XLEN;
parameter int USER_ACC_W            = 1;
parameter int WRITE_ACC_W           = 1;
parameter int TLB_UPDATE_VTID_ARG_W = PAGE_ADDR_W - USER_ACC_W - WRITE_ACC_W;
parameter int AXI_ADDR_W            = XLEN;
parameter int BANK_REQ_W            = BANK_ADDR_W + PORT_IDX_W + 1 + 1 + 1 + 1 + (XLEN/8) + XLEN + THRD_W;

typedef struct packed {
    logic [VIR_ADDR_W-1:0]    addr;
    logic                     is_lr;
    logic                     is_sc;
    logic                     we;
    logic [XLEN/8-1:0]        wstrb;
    logic [XLEN-1:0]          wdata;
    logic [THRD_W-1:0]        thrd;
    logic [PRIV_MODE_W-1:0]   priv;
} req_t;

typedef struct packed {
    logic [BANK_ADDR_W-1:0]   baddr;
    logic [PORT_IDX_W-1:0]    port;
    logic                     is_page_resp;
    logic                     is_lr;
    logic                     is_sc;
    logic                     we;
    logic [XLEN/8-1:0]        wstrb;
    logic [XLEN-1:0]          wdata;
    logic [THRD_W-1:0]        thrd;
} bank_req_t;

typedef struct packed {
    logic [PRIV_MODE_W-1:0]   perm;     // permission bits
    logic                     user_acc;
    logic                     writable;
    logic [1:0]               rrpv;     // re reference prediction value
    logic                     valid;
    logic [VTID_W-1:0]        vtid;
    logic [PPN_W-1:0]         ppn;
    logic [VPN_W-1:0]         vpn;
} va2pa_t;

typedef struct packed {
    logic [PORT_IDX_W-1:0]    port;
    logic [THRD_W-1:0]        thrd;
    va2pa_t                   entry;
} page_table_refill_t;

typedef enum logic [PAGE_MSG_TYPE_W-1:0] {
    PAGE_MSG_FAULT        = 4'd1,
    PAGE_MSG_TLB_UPDATE   = 4'd2,
    PAGE_MSG_PAGE_LOAD    = 4'd3,
    PAGE_MSG_PAGE_EVICT   = 4'd4,
    PAGE_MSG_VTID_UPDATE  = 4'd5
} page_msg_type_e;

typedef struct packed {
    logic [PAGE_MSG_DATA_W-1:0]                               padding;
    page_msg_type_e                                           msg_type;
} generic_page_msg_t;

typedef struct packed {
    logic [PAGE_MSG_DATA_W-VPN_W-THRD_W-1:0]                  padding;
    logic [THRD_W-1:0]                                        thrd_id;
    logic [VPN_W-1:0]                                         vpn;
    page_msg_type_e                                           msg_type;
} page_fault_msg_t;

typedef struct packed {
    logic [PAGE_MSG_DATA_W-VPN_W-PPN_W-VTID_W-USER_ACC_W-WRITE_ACC_W-1:0] padding;
    logic                                                     user_acc;
    logic                                                     writable;
    logic [VTID_W-1:0]                                        vtid;
    logic [PPN_W-1:0]                                         ppn;
    logic [VPN_W-1:0]                                         vpn;
    page_msg_type_e                                           msg_type;
} tlb_update_msg_t;

typedef struct packed {
    logic [PAGE_MSG_DATA_W-AXI_ADDR_W-PPN_W-THRD_W-1:0]       padding;
    logic [THRD_W-1:0]                                        thrd_id;
    logic [AXI_ADDR_W-1:0]                                    axi_addr;
    logic [PPN_W-1:0]                                         ppn;
    page_msg_type_e                                           msg_type;
} page_transfer_msg_t;

typedef struct packed {
    logic [PAGE_MSG_DATA_W-VTID_W-THRD_W-1:0]                 padding;
    logic [VTID_W-1:0]                                        vtid;
    logic [THRD_W-1:0]                                        thrd_id;
    page_msg_type_e                                           msg_type;
} vtid_update_msg_t;



typedef struct packed {
    logic                   we;
    logic [THRD_W-1:0]      thrd;
    logic                   is_lr;
    logic                   is_sc;
    logic [VIR_ADDR_W-1:0]  addr;
    logic [XLEN/8-1:0]      wstrb;
    logic [XLEN-1:0]        wdata;
    logic [PRIV_MODE_W-1:0] priv;
} mem_req_t;


typedef struct packed {
    logic [THRD_W-1:0]      thrd;
    logic                   sc_succ;
    logic [XLEN-1:0]        rdata;
} mem_resp_t;


typedef struct packed {
    logic [PAGE_MSG_W-1:0]  page_msg;
} mem_msg_req_t;

typedef struct packed {
    logic [PAGE_MSG_W-1:0]  page_msg;
} mem_msg_resp_t;

typedef mem_msg_resp_t mem_page_resp_t;


endpackage: memory_pkg

