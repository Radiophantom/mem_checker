vlib work

vlog -sv -f package_files
vlog -sv -f rtl_files
vlog -sv -f tb_files

vsim -voptargs="+acc" mem_checker_tb
#vsim mem_checker_tb

do wave.do

run -all