#ifndef RCU_H
#define RCU_H

typedef struct rcu_head rcu_head_t;

struct rcu_head {
    rcu_head_t *next;
    void (*func)(rcu_head_t *head);
};

void rcu_init(void);
void rcu_read_lock(void);
void rcu_read_unlock(void);
void synchronize_rcu(void);
void call_rcu(rcu_head_t *head, void (*func)(rcu_head_t *head));

#define rcu_dereference(pointer) \
    __atomic_load_n(&(pointer), __ATOMIC_ACQUIRE)
#define rcu_assign_pointer(pointer, value) \
    __atomic_store_n(&(pointer), (value), __ATOMIC_RELEASE)

#endif /* RCU_H */
