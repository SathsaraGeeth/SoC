#ifndef DEV_H
#define DEV_H

#include "../../fs/file.h"
#include <stdint.h>

/* device registry — name → vnode */
typedef struct {
    char      name[16];   /* e.g. "uart0", "null", "zero" */
    vnode_t  *vnode;
    uint32_t  used;
} dev_entry_t;

#define DEV_PATH_PREFIX  "/dev/"

void      dev_init(void);
int       dev_register(const char *name, vnode_ops_t *ops, void *data);
vnode_t  *dev_find(const char *name);    /* name without /dev/ prefix */
int       dev_name_at(uint32_t index, char *name, uint32_t max);
void      dev_list(void);

#endif
