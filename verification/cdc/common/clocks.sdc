# DMCTP currently exposes one functional clock at the SoC boundary.
create_clock -name i_clk -period 10.000 [get_ports i_clk]
