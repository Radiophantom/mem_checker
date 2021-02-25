create_clock -name sys_clk -period 10.000 [get_ports {clk_sys_i}]
create_clock -name mem_clk -period 4.348 [get_ports {clk_mem_i}]
set_clock_groups -asynchronous -group [get_clocks {mem_clk}] -group [get_clocks {sys_clk}]
set_false_path -from [get_ports {rst_i}] -to [get_clocks {mem_clk sys_clk}]