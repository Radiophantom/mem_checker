`include "../interface/amm_if.sv"

import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class driver();

virtual amm_if #(
  .ADDR_W   ( 4   ),
  .DATA_W   ( 32  )
) amm_if_v;

mailbox       gen2driv;
mailbox       driv2scoreb;

random_scenario   rnd_scen_obj;

test_result_t     test_result;

bit [31 : 0]  rd_data;

function new(
  virtual amm_if #(
    .ADDR_W   ( 4   ),
    .DATA_W   ( 32  )
  ) amm_if_v,
  mailbox gen2driv,
  mailbox driv2scoreb,
  event   test_started,
  event   test_finished
);
  this.amm_if_v       = amm_if_v;
  this.gen2driv       = gen2driv;
  this.driv2scoreb    = driv2scoreb;
  this.test_started   = test_started;
  this.test_finished  = test_finished;
  init_interface();
endfunction

local function automatic void init_interface();
  amm_if_v.read       = 1'b0;
  amm_if_v.write      = 1'b0;
  amm_if_v.address    = '0;
  amm_if_v.writedata  = '0;
  amm_if_v.readdata   = '0;
endfunction : init_interface

local task automatic wr_word(
      int           wr_addr,
  ref bit [31 : 0]  wr_data
);
  amm_if_v.address    <= wr_addr;
  amm_if_v.writedata  <= wr_data;
  amm_if_v.write      <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;
endtask : wr_word

local task automatic rd_word(
  int rd_addr
);
  amm_if_v.address  <= rd_addr;
  amm_if_v.read     <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.read     <= 1'b0;
  @( posedge amm_if_v.clk );
  rd_data = amm_if_v.readdata;
endtask : rd_word

local task automatic poll_finish_bit();
  do
    rd_word( CSR_TEST_FINISH );
  while( rd_data == 0 );
endtask : poll_finish_bit

local task automatic start_test();
  wr_word( CSR_TEST_PARAM,  rnd_scen_obj.test_param[CSR_TEST_PARAM] );
  wr_word( CSR_SET_ADDR,    rnd_scen_obj.test_param[CSR_SET_ADDR]   );
  wr_word( CSR_SET_DATA,    rnd_scen_obj.test_param[CSR_SET_DATA]   );
  wr_word( CSR_TEST_START,  32'd1                                   );
endtask : start_test

local task automatic save_test_result();
  for( int i = CSR_TEST_RESULT; i < CSR_RD_REQ; i++ )
    begin
      rd_word( i );
      test_result[i] = rd_data;
    end
endtask : save_test_result

task automatic run();
  forever
    begin
      gen2driv.get( rnd_scen_obj );
      start_test();
      -> test_started;
      poll_finish_bit();
      -> test_finished;
      save_test_result();
      driv2scoreb.put( test_result );
    end
endtask : run

endclass : driver
