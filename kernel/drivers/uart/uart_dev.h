#ifndef UART_DEV_H
#define UART_DEV_H

#include "../../fs/file.h"

/* register /dev/uart0 into the device table */
void uart_dev_init(void);

/* vnode_ops for uart — also used to set up fd 0/1/2 */
extern vnode_ops_t uart_vnode_ops;

#endif
