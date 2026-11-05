# Native 8x8 INT8 matrix multiplication
delegation tid=0
matmul native mac=int8 a_tiles=1 b_tiles=1 a=0x1000 b=0x4000 d=0x8000
release
