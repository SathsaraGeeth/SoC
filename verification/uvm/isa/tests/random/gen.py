#!/usr/bin/env python3
import random
import sys

def rand_reg(exclude=None):
    exclude = exclude or []
    r = random.randint(1, 31)
    while r in exclude:
        r = random.randint(1, 31)
    return f'r{r}'

def gen_instruction(base_reg='r28'):
    r_types = ['add.i64', 'sub.i64', 'and.64', 'or.64', 'xor.64',
               'sl.i64', 'sr.i64', 'slt.i64']
    # SLTI.i64 is architectural, but the current in-tree assembler does not
    # expose its custom mnemonic yet. Keep random generation executable until
    # that separate compiler gap is closed.
    i_types = ['addi.i64', 'andi.64', 'ori.64', 'xori.64',
               'sli.i64', 'sri.i64']
    
    inst_type = random.choice(['R', 'I', 'L', 'S'])
    
    rd = rand_reg(exclude=[28])
    rs1 = rand_reg(exclude=[28])
    rs2 = rand_reg(exclude=[28])
    
    if inst_type == 'R':
        mnemonic = random.choice(r_types)
        return f"    {mnemonic} {rd}, {rs1}, {rs2}"
    elif inst_type == 'I':
        mnemonic = random.choice(i_types)
        imm = random.randint(-2048, 2047)
        if mnemonic in ['sli.i64', 'sri.i64']:
            imm = random.randint(0, 63)
        return f"    {mnemonic} {rd}, {rs1}, {imm}"
    elif inst_type == 'L':
        offset = random.randint(0, 63) * 8
        return f"    load.i64 {rd}, {offset}({base_reg})"
    elif inst_type == 'S':
        offset = random.randint(0, 63) * 8
        return f"    store.64 {rs2}, {offset}({base_reg})"
    return "    nop"

def main():
    num_insts = 1000
    seed = 1
    if len(sys.argv) > 1:
        num_insts = int(sys.argv[1])
    if len(sys.argv) > 2:
        seed = int(sys.argv[2], 0)
    random.seed(seed)
        
    print(".section .text")
    print(".global _start")
    print("_start:")
    
    # Initialize base_reg (r28) to point to .data
    print("    la r28, test_data")
    # Initialize all registers to avoid X states in RTL
    for i in range(1, 32):
        if i != 28:
            print(f"    addi.i64 r{i}, r0, 0")

    # Exercise reservation behavior before the randomized body:
    # an SC without an LR fails, a matching LR/SC may succeed, a repeated SC
    # fails, and an ordinary overlapping store invalidates a reservation.
    print("    addi.i64 r27, r0, 1")
    print("    condstore.64 r26, r27, (r28)")
    print("    load.i64.res r25, (r28)")
    print("    condstore.64 r24, r27, (r28)")
    print("    condstore.64 r23, r27, (r28)")
    print("    load.i64.res r22, (r28)")
    print("    store.64 r27, 0(r28)")
    print("    condstore.64 r21, r27, (r28)")
            
    for _ in range(num_insts):
        print(gen_instruction(base_reg='r28'))
        
    # Infinite loop at the end
    print("1:")
    print("    jump.rel.dir r0, 1b")
    
    print(".section .data")
    print(".align 4")
    print("test_data:")
    print("    .fill 512, 1, 0")

if __name__ == '__main__':
    main()
