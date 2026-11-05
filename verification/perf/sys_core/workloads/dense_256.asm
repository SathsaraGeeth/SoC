# Dense INT8 256x256 matrix multiplication
delegation tid=0
matmul dense mac=int8 a_tiles=32 b_tiles=32 a=0x200000 b=0x210000 d=0x220000
release
