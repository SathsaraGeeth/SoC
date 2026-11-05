/* 
 * kernel/boot/common/load.c
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
 * 1. Uses the hardware page engine - which connects memory system with presistant block device.
 */

#include <load.h>

void load_block(uint32_t src_ba, uint32_t dest_ppn) {
    csr_write(CSR_PAGE_MSG_ARG0, src_ba);
    csr_write(CSR_PAGE_MSG_ARG1, dest_ppn);
    csr_write(CSR_PAGE_MSG_CMD, 3);
    wfi();
}

