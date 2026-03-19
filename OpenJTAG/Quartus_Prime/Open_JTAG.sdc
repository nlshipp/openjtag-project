set sys_clk "|Open_JTAG|pll:inst3|altpll:altpll_component"

create_clock -name {clk_50} -period 20.000 [get_ports {CLK_50}]
# derive_clocks -period 20.833
derive_pll_clocks
derive_clock_uncertainty