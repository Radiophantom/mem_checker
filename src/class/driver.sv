`include "../interface/amm_if.sv"

import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class driver;

virtual amm_if #(
  .ADDR_W   ( 4   ),
  .DATA_W   ( 32  )
) amm_if_v;

mailbox   gen2driv_mbx;
mailbox   driv2scb_test_mbx;
mailbox   driv2scb_stat_mbx;

typedef class random_scenario;
typedef class statistics;

random_scenario   rnd_scen_obj;
statistics        stat_obj;

event test_started;
event test_finished;

function new(
  virtual amm_if #(
    .ADDR_W   ( 4   ),
    .DATA_W   ( 32  )
  ) amm_if_v,
  mailbox gen2driv_mbx,
  mailbox driv2scb_test_mbx,
  mailbox driv2scb_stat_mbx,
  event   test_started,
  event   test_finished
);
  this.amm_if_v           = amm_if_v;
  this.gen2driv_mbx       = gen2driv_mbx;
  this.driv2scb_test_mbx  = driv2scb_test_mbx;
  this.driv2scb_stat_mbx  = driv2scb_stat_mbx;
  this.test_started       = test_started;
  this.test_finished      = test_finished;
  init_interface();
endfunction

local function automatic void init_interface();
  amm_if_v.read           = 1'b0;
  amm_if_v.write          = 1'b0;
  amm_if_v.readdatavalid  = 1'b0;
  amm_if_v.address        = '0;
  amm_if_v.writedata      = '0;
  amm_if_v.readdata       = '0;
endfunction : init_interface

local task automatic wr_word(
  int           wr_addr,
  bit [31 : 0]  wr_data
);
  amm_if_v.address    <= wr_addr;
  amm_if_v.writedata  <= wr_data;
  amm_if_v.write      <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.write      <= 1'b0;
endtask : wr_word

local task automatic rd_word(
  input  int          rd_addr,
  output bit [31 : 0] rd_data
);
  amm_if_v.address  <= rd_addr;
  amm_if_v.read     <= 1'b1;
  @( posedge amm_if_v.clk );
  amm_if_v.read     <= 1'b0;
  do
    @( posedge amm_if_v.clk );
  while( !amm_if_v.readdatavalid );
  rd_data = amm_if_v.readdata;
endtask : rd_word

local task automatic poll_finish_bit();
  bit [31 : 0] rd_data;
  do
    rd_word( CSR_TEST_FINISH, rd_data );
  while( rd_data != 1 );
endtask : poll_finish_bit

local task automatic start_test();
  wr_word( CSR_TEST_PARAM,  rnd_scen_obj.test_param_registers[CSR_TEST_PARAM] );
  wr_word( CSR_SET_ADDR,    rnd_scen_obj.test_param_registers[CSR_SET_ADDR  ] );
  wr_word( CSR_SET_DATA,    rnd_scen_obj.test_param_registers[CSR_SET_DATA  ] );
  wr_word( CSR_TEST_START,  32'd1                                             );
endtask : start_test

local task automatic save_test_result();
  stat_obj = new();

  for( int i = CSR_TEST_RESULT; i <= CSR_ERR_DATA; i++ )
    begin
      rd_word( i, rnd_scen_obj.test_result_registers[i] );
    end
  for( int i = CSR_WR_TICKS; i <= CSR_RD_REQ; i++ )
    begin
      rd_word( i, stat_obj.stat_registers[i] );
    end
endtask : save_test_result

task automatic run();
  fork
    forever
      begin
        gen2driv_mbx.get( rnd_scen_obj );
        start_test();
        -> test_started;
        poll_finish_bit();
        -> test_finished;
        save_test_result();
        driv2scb_test_mbx.put( rnd_scen_obj );
        driv2scb_stat_mbx.put( stat_obj     );
      end
  join_none
endtask : run

endclass : driver