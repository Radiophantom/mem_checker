vlib work
vlog -sv {./src/interface/amm_if.sv}
vlog -sv -f package_files
vlog -sv -f class_files
vlog -sv -f rtl_files
vlog -sv -f tb_files

vsim -voptargs="+acc" mem_checker_tb