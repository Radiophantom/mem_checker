onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {CSR interface}
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/clk
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/address
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/read
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/write
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/writedata
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/readdatavalid
add wave -noupdate -height 27 /mem_checker_tb/amm_if_csr/readdata
add wave -noupdate -divider {MEMORY interface}
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/clk
add wave -noupdate -height 27 -radix hexadecimal /mem_checker_tb/amm_if_mem/address
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/read
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/write
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/waitrequest
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/writedata
add wave -noupdate -height 27 -radix unsigned /mem_checker_tb/amm_if_mem/burstcount
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/byteenable
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/readdatavalid
add wave -noupdate -height 27 /mem_checker_tb/amm_if_mem/readdata
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {42724000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 337
configure wave -valuecolwidth 100
configure wave -justifyvalue right
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {4806216250 ps} {6731601250 ps}
