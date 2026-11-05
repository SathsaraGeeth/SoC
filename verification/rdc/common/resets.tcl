# Tool-neutral reset intent for the current SoC interface.
set_reset -name i_rst_n -active_low [get_ports i_rst_n]
set_reset -name uart_rst_n -active_low \
    [get_pins uart_reset_sync/o_rst_n]

foreach_in_collection pin [get_pins -hierarchical */cluster_reset_sync/o_rst_n] {
    set_reset -active_low $pin
}
foreach_in_collection pin [get_pins -hierarchical */memory_reset_sync/o_rst_n] {
    set_reset -active_low $pin
}
foreach_in_collection pin [get_pins -hierarchical */sys_array_reset_sync/o_rst_n] {
    set_reset -active_low $pin
}
