# System-array address-generator UVM environment

The environment instantiates the A, B, and writeback parameterizations.  Its
scoreboard predicts every emitted address, reuse/dense bit, MAC type, flag, and
thread tag while randomized backpressure exercises valid/data holding.
