#ifndef DMCTP_PROC_SCHED_ENTITY_H
#define DMCTP_PROC_SCHED_ENTITY_H

#include <stdint.h>

struct load_weight {
    uint64_t weight;
    uint32_t inv_weight;
};

struct rb_node {
    struct rb_node *left;
    struct rb_node *right;
    struct rb_node *parent;
    unsigned char color;
};

struct list_head {
    struct list_head *next;
    struct list_head *prev;
};

/*
 * Original draft (kept for design history):
 *
 * struct sched_entity {
 *     struct weight    weight;
 *     uint64_t         exec_start;
 *     uint64_t         sum_exec_runtime;
 *     uint64_t         vruntime;
 *     uint64_t         deadline;
 *     uint64_t         slice;
 *     struct rb_node   run_node;
 *     struct list_head group_node;
 * };
 */
struct sched_entity {
    struct load_weight load;
    uint64_t exec_start;
    uint64_t sum_exec_runtime;
    uint64_t vruntime;
    uint64_t deadline;
    uint64_t slice;
    struct rb_node run_node;
    struct list_head group_node;
    unsigned int on_rq;
};

#endif
