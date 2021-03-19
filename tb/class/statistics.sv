//*********************************************************//
// Class allows to gather and save transaction statistics  //
//*********************************************************//

import rtl_settings_pkg::*;

class statistics;

//*****************************
// Class variables declaration
//*****************************

bit [31 : 0] stat_registers [CSR_RD_REQ : CSR_WR_TICKS];

//*****************************
// Class allocating
//*****************************

function new();
	// initialize minimum delay register with maximum value
	stat_registers[CSR_MIN_DEL] = 16'hFF_FF;
endfunction : new

//*****************************
// Statistic gather tasks
//*****************************

task automatic wr_ticks_count();
	stat_registers[CSR_WR_TICKS]++;
endtask : wr_ticks_count

task automatic wr_units_count( int units );
	stat_registers[CSR_WR_UNITS] += units;
endtask : wr_units_count

task automatic rd_ticks_count();
	stat_registers[CSR_RD_TICKS]++;
endtask : rd_ticks_count

task automatic rd_words_count();
	stat_registers[CSR_RD_WORDS]++;
endtask : rd_words_count

task automatic rd_req_count();
	stat_registers[CSR_RD_REQ]++;
endtask : rd_req_count

task automatic rd_delay_count( int delay );
	if( delay < stat_registers[CSR_MIN_DEL] )
		stat_registers[CSR_MIN_DEL] = delay;
	if( delay > stat_registers[CSR_MAX_DEL] )
		stat_registers[CSR_MAX_DEL] = delay;
	stat_registers[CSR_SUM_DEL] += delay;
endtask : rd_delay_count

endclass : statistics