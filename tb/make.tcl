vlib work

vlog -sv -f package_files
vlog -sv -f rtl_files
vlog -sv -f tb_files +incdir+./class+./interface

vsim -voptargs="+acc" mem_checker_tb

do wave.do

run -all