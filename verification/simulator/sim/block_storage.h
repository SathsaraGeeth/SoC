#pragma once
#include "Vsoc.h"
#include <cstdint>
#include <map>

class PageEngineModel {
public:
    std::map<uint64_t, uint64_t> memory;
    explicit PageEngineModel(uint64_t size_bytes) : max_size(size_bytes) {}

    void eval(Vsoc* top) {
        top->m_axi4_page_awready = !wr_active && !b_valid;
        top->m_axi4_page_wready  = wr_active && !b_valid;
        top->m_axi4_page_bvalid  = b_valid;
        top->m_axi4_page_bid     = b_id;
        top->m_axi4_page_bresp   = 0;

        top->m_axi4_page_arready = !rd_active;
        top->m_axi4_page_rvalid  = rd_active;
        top->m_axi4_page_rdata   = rd_active ? memory[(rd_addr + rd_beat * 8) / 8] : 0;
        top->m_axi4_page_rid     = rd_id;
        top->m_axi4_page_rresp   = 0;
        top->m_axi4_page_rlast   = rd_active && (rd_beat == rd_len);

        if (top->m_axi4_page_awvalid && top->m_axi4_page_awready) {
            wr_active = true;
            wr_addr = top->m_axi4_page_awaddr;
            wr_len = top->m_axi4_page_awlen;
            wr_beat = 0;
            wr_id = top->m_axi4_page_awid;
        }
        if (wr_active && top->m_axi4_page_wvalid && top->m_axi4_page_wready) {
            uint64_t &word = memory[(wr_addr + wr_beat * 8) / 8];
            const uint64_t data = top->m_axi4_page_wdata;
            const uint8_t strb = top->m_axi4_page_wstrb;
            for (unsigned byte = 0; byte < 8; ++byte) {
                if (strb & (1u << byte)) {
                    word = (word & ~(UINT64_C(0xff) << (byte * 8))) |
                           (((data >> (byte * 8)) & 0xff) << (byte * 8));
                }
            }
            if (top->m_axi4_page_wlast || wr_beat == wr_len) {
                wr_active = false;
                b_valid = true;
                b_id = wr_id;
            } else {
                ++wr_beat;
            }
        }
        if (b_valid && top->m_axi4_page_bready)
            b_valid = false;

        if (top->m_axi4_page_arvalid && top->m_axi4_page_arready) {
            rd_active = true;
            rd_addr = top->m_axi4_page_araddr;
            rd_len = top->m_axi4_page_arlen;
            rd_beat = 0;
            rd_id = top->m_axi4_page_arid;
        } else if (rd_active && top->m_axi4_page_rready) {
            if (rd_beat == rd_len)
                rd_active = false;
            else
                ++rd_beat;
        }
    }

private:
    uint64_t max_size;
    bool rd_active = false;
    uint64_t rd_addr = 0;
    uint8_t rd_len = 0;
    uint8_t rd_beat = 0;
    uint8_t rd_id = 0;
    bool wr_active = false;
    uint64_t wr_addr = 0;
    uint8_t wr_len = 0;
    uint8_t wr_beat = 0;
    uint8_t wr_id = 0;
    bool b_valid = false;
    uint8_t b_id = 0;
};
