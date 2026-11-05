#ifndef DMCTP_STDIO_H
#define DMCTP_STDIO_H

int puts(const char *s);
int printf(const char *fmt, ...);

/*
 * DMCTP extension:
 *   %F  fp8_e4m3_t promoted to int, printed as an exact decimal value.
 */
int getchar(void);

#endif
