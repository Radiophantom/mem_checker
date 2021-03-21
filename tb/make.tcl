vlib work

vlog -sv -f files +incdir+./class+./interface

vsim -voptargs="+acc" mem_checker_tb

do wave.do

run -all