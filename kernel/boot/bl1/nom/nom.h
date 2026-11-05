#ifndef BL1_NOM_H
#define BL1_NOM_H

#include <stdint.h>

#include <stdbool.h>

void bl1_nom_secondary_listen_loop(uint32_t tid, uint32_t region_id);
void bl1_nom_transfer_bl2a_to_region(uint32_t tid, uint32_t target_region);
void bl1_nom_transfer_bl2_to_region(uint32_t tid, uint32_t target_region);
void bl1_nom_transfer_bl2_broadcast(uint32_t tid);
bool bl1_nom_request_and_verify_checksum(uint32_t tid, uint32_t target_region);

#endif /* BL1_NOM_H */
