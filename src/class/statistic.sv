import rtl_settings_pkg::*;

class statistics();

bit [CSR_RD_REQ : CSR_WR_TICKS][31 : 0] stat_registers;

stat_registers[CSR_MIN_DEL] = 32'hFF_FF_FF_FF;

function automatic void wr_ticks_cnt(  ref int ticks_amount  );
  stat_registers[CSR_WR_TICKS] += ticks_amount;
endfunction : wr_ticks_cnt

function automatic void wr_units_cnt(  ref int units_amount  );
  stat_registers[CSR_WR_UNITS] += units_amount;
endfunction : wr_bytes_cnt

function automatic void rd_ticks_cnt(  ref int ticks_amount  );
  stat_registers[CSR_RD_TICKS] += ticks_amount;
endfunction : rd_bytes_cnt

function automatic void rd_words_cnt(  ref int words_amount  );
  stat_registers[CSR_RD_WORDS] += words_amount;
endfunction : rd_bytes_cnt

function automatic void rd_req_cnt  (  ref int req_amount    );
  stat_registers[CSR_RD_REQ]   += req_amount;
endfunction : rd_req_amount_cnt

function automatic void min_delay_collect(  ref int delay    );
  if( delay < stat_registers[CSR_MIN_DEL] )
   stat_registers[CSR_MIN_DEL] = delay;
endfunction : min_delay_collect

function automatic void max_delay_collect(  ref int delay    );
  if( delay > stat_registers[CSR_MAX_DEL] )
   stat_registers[CSR_MAX_DEL] = delay;
endfunction : max_delay_collect

endclass : statistics
