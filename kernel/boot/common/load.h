/*
 * Comments:
 * 1. Uses the hardware page engine - which connects memory system with presistant block device.
 */


#include <stdint.h>
#include <soc.h>
#include <regs.h>

void load_block(uint32_t lba, uint32_t dest_ppn);
