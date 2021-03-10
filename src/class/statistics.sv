import rtl_settings_pkg::*;

class statistics;

bit [CSR_RD_REQ : CSR_WR_TICKS][31 : 0] stat_registers;

// function new();
// 	stat_registers[CSR_MIN_DEL] = 16'hFF_FF;
// endfunction

endclass : statistics