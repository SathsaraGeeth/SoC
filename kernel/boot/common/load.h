/* 
 * kernel/boot/common/load.h
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


#include <stdint.h>
#include <soc.h>
#include <regs.h>

void load_block(uint32_t lba, uint32_t dest_ppn);
