# Dense 8x8 INT8 matrix multiplication
delegation tid=0
matmul dense mac=int8 a_tiles=1 b_tiles=1 a=0x11000 b=0x14000 d=0x18000
release
