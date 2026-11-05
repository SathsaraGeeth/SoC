# UART reset is derived from i_rst_n with asynchronous assertion and
# synchronous release in uart_clk. The UART domain may leave reset only after
# the system reset source has deasserted.
set_reset_relation -source i_rst_n -derived uart_rst_n \
    -async_assert -sync_release

# Every generated cluster, memory and systolic-array reset has the same
# asynchronous source and an independent synchronous-release chain.
set_reset_relation -source i_rst_n \
    -derived [get_pins -hierarchical */cluster_reset_sync/o_rst_n] \
    -async_assert -sync_release
set_reset_relation -source i_rst_n \
    -derived [get_pins -hierarchical */memory_reset_sync/o_rst_n] \
    -async_assert -sync_release
set_reset_relation -source i_rst_n \
    -derived [get_pins -hierarchical */sys_array_reset_sync/o_rst_n] \
    -async_assert -sync_release
