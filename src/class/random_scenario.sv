`include "./bathtube_distribution.sv"

import tb_settings_pkg::*;
import rtl_settings_pkg::*;

class random_scenario();

bathtube_distribution   bath_dist_obj;

localparam int MAX_BURST_VAL      = ( 2**( AMM_BURST_W - 1 ) );

localparam int MAX_BURST_BYTE_VAL = ( ADDR_TYPE == "BYTE" ) ? ( MAX_BURST_VAL            - 1 ):
                                                              ( MAX_BURST_VAL * DATA_B_W - 1 );

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
  burst_count   <= MAX_BURST_VAL;
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
    begin
      error_enable dist {
        0 := ( 100 - err_probability ),
        1 := ( err_probability       )
      };
    end
  else
    error_enable = 0;
}

bit [CSR_ERR_DATA : CSR_TEST_RESULT][31 : 0] test_result_registers;
bit [CSR_SET_DATA :  CSR_TEST_PARAM][31 : 0] test_param_registers;

function automatic void set_test_mode_probability(
  int read_only_mode  = 30,
  int write_only_mode = 30,
  int write_read_mode = 40
);
  this.read_only_mode   = read_only_mode;
  this.write_only_mode  = write_only_mode;
  this.write_read_mode  = write_read_mode;
endfunction

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
endfunction

function automatic void set_err_probability(
  int err_probability   = 20
);
  this.err_probability  = err_probability;
endfunction

function automatic void prep_test_param();
  test_param_registers[CSR_TEST_PARAM]  = { trans_amount, test_mode, addr_mode, data_mode, burstcount };
  test_param_registers[CSR_SET_ADDR  ]  = addr_ptrn;
  test_param_registers[CSR_SET_DATA  ]  = data_ptrn;
endfunction : prep_test_param

function automatic void post_randomize();
  bath_dist_obj = new();
  bath_dist_obj.set_dist_parameters( MAX_BURST_VAL );
  bath_dist_obj.randomize();
  err_byte_num  = bath_dist_obj.value;
  bath_dist_obj = null;
endfunction : post_randomize

endclass : random_scenario
