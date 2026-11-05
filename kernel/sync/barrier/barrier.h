/*
 * Comments:
 * 1. both smp and non smp versions are equivalent as 
 *    memory is weakly ordered
 */

#ifndef BARRIER_H
#define BARRIER_H

void mb(void);
void rmb(void);
void wmb(void);

void smp_mb(void);
void smp_rmb(void);
void smp_wmb(void);

#endif /* BARRIER_H */