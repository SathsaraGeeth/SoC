# Tool-neutral intent; translate set_reset for the selected signoff tool.
# The SoC input reset asserts all domains asynchronously.  Each reset_sync
# instance then provides a locally synchronized reset release.
set_reset -name i_rst_n -active_low [get_ports i_rst_n]
set_reset -name rst_fabric_n -active_low \
    [get_pins -hierarchical */fabric_reset_sync/o_rst_n]
set_reset -name rst_cluster_n -active_low \
    [get_pins -hierarchical */gen_cluster_reset*/cluster_reset_sync/o_rst_n]
set_reset -name rst_mem_n -active_low \
    [get_pins -hierarchical */gen_memory_clock_reset*/memory_reset_sync/o_rst_n]
set_reset -name rst_periph_n -active_low \
    [get_pins -hierarchical */periph_reset_sync/o_rst_n]
set_reset -name rst_accel_n -active_low \
    [get_pins -hierarchical */accel_reset_sync/o_rst_n]
