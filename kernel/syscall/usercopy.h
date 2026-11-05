/*
 * Comments:
 * 1. the dispatcher does not touch user memory,
 *    but needed for syscalls implementations
 *    these defines safe copy to/from user space
 */

#ifndef DMCTP_USERCOPY_H
#define DMCTP_USERCOPY_H

#include <stddef.h>

int copy_from_user(void *destination, const void *source, size_t size);
int copy_to_user(void *destination, const void *source, size_t size);
int copy_string_from_user(char *destination, const char *source, size_t capacity);

#endif
