.section .text

.global mb
.global rmb
.global wmb
.global smp_mb
.global smp_rmb
.global smp_wmb

mb:
    fence.d.ls.ls
    jump.abs        r0, 0(r1)

rmb:
    fence.d.l.l
    jump.abs        r0, 0(r1)

wmb:
    fence.d.s.s
    jump.abs        r0, 0(r1)

smp_mb:
    fence.d.ls.ls
    jump.abs        r0, 0(r1)

smp_rmb:
    fence.d.l.l
    jump.abs        r0, 0(r1)

smp_wmb:
    fence.d.s.s
    jump.abs        r0, 0(r1)
