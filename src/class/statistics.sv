import rtl_settings_pkg::*;

class statistics;

bit [31 : 0] stat_registers [CSR_RD_REQ : CSR_WR_TICKS];

endclass : statistics