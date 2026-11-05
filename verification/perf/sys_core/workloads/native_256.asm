# Native INT8 256x256 matrix multiplication, software sequenced 8x8 tiles
delegation tid=0
matmul native mac=int8 a_tiles=32 b_tiles=32 a=0x100000 b=0x110000 d=0x120000
release
