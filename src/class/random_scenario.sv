`include "./bathtube_distribution.sv"

import tb_settings_pkg::*;
import rtl_settings_pkg::*;

class random_scenario;

bathtube_distribution bath_dist_obj;

localparam int MAX_BURST_VAL = 2**( AMM_BURST_W - 1 );

bit [31 : 0]  test_result_registers [CSR_ERR_DATA : CSR_TEST_RESULT];
bit [31 : 0]  test_param_registers  [CSR_SET_DATA :  CSR_TEST_PARAM];

int max_burst_byte_val; 

int read_only_mode;
int write_only_mode;
int write_read_mode;

int fix_addr_mode;
int rnd_addr_mode;
int run_1_addr_mode;
int run_0_addr_mode;
int inc_addr_mode;

int err_probability;

rand  bit   [15 : 0]            trans_amount;
rand  bit   [1  : 0]            test_mode;
rand  bit   [2  : 0]            addr_mode;
rand  bit                       data_mode;
rand  bit   [9  : 0]            burstcount;

rand  bit                       err_enable;
rand  bit   [15 : 0]            err_trans_num;
      int                       err_byte_num;

rand  bit   [ADDR_W - 1 : 0]    addr_ptrn;
rand  bit   [7  : 0]            data_ptrn;

constraint base_constraints {
  burstcount    <  MAX_BURST_VAL;
  trans_amount  <  2**5;
  err_trans_num <= trans_amount;
}

constraint test_mode_constraint {
  test_mode dist {
    0 := 0,
    1 := read_only_mode,
    2 := write_only_mode,
    3 := write_read_mode
  };
}

constraint addr_mode_constraint {
  addr_mode dist {
    0     := fix_addr_mode,
    1     := rnd_addr_mode,
    2     := run_0_addr_mode,
    3     := run_1_addr_mode,
    4     := inc_addr_mode,
    [5:7] := 0
  };
}

constraint error_enable_constraint {
  if( test_mode == 3 )
    err_enable dist {
      0 := ( 100 - err_probability ),
      1 := ( err_probability       )
    };
  else
    err_enable dist {
      0 := 100,
      1 := 0
    };
}

function automatic void set_test_mode_probability(
  int read_only_mode  = 30,
  int write_only_mode = 30,
  int write_read_mode = 40
);
  this.read_only_mode   = read_only_mode;
  this.write_only_mode  = write_only_mode;
  this.write_read_mode  = write_read_mode;
endfunction : set_test_mode_probability

function automatic void set_addr_mode_probability(
  int fix_addr_mode   = 20,
  int rnd_addr_mode   = 20,
  int run_0_addr_mode = 20,
  int run_1_addr_mode = 20,
  int inc_addr_mode   = 20
);
  this.fix_addr_mode    = fix_addr_mode;
  this.rnd_addr_mode    = rnd_addr_mode;
  this.run_0_addr_mode  = run_0_addr_mode;
  this.run_1_addr_mode  = run_1_addr_mode;
  this.inc_addr_mode    = inc_addr_mode;
endfunction : set_addr_mode_probability

function automatic void set_err_probability(
  int err_probability   = 20
);
  this.err_probability  = err_probability;
endfunction : set_err_probability

function automatic void prep_test_param();
  test_param_registers[CSR_TEST_PARAM] = { trans_amount, test_mode, addr_mode, data_mode, burstcount };
  test_param_registers[CSR_SET_ADDR  ] = addr_ptrn;
  test_param_registers[CSR_SET_DATA  ] = data_ptrn;
endfunction : prep_test_param

function automatic void err_byte_num_set();
  if( ADDR_TYPE == "BYTE" )
    max_burst_byte_val = ( burstcount                        );
  else
    max_burst_byte_val = ( ( burstcount + 1 ) * DATA_B_W - 1 );	
  bath_dist_obj = new();
  bath_dist_obj.set_edge( max_burst_byte_val );
  err_byte_num  = bath_dist_obj.get_value();
  bath_dist_obj = null;
endfunction : err_byte_num_set

function automatic void post_randomize();
  prep_test_param();
  err_byte_num_set();
endfunction : post_randomize

endclass : random_scenario