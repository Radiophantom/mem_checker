`include "./random_scenario.sv"
`include "./statistics.sv"
`include "./generator.sv"
`include "./driver.sv"
`include "./amm_memory.sv"
`include "./monitor.sv"
`include "./scoreboard.sv"

import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class environment;

generator gen;
driver driv;
amm_memory mem;
monitor mon;
scoreboard scb;

mailbox gen2driv_mbx;
mailbox gen2mem_mbx;
mailbox driv2scb_test_mbx;
mailbox driv2scb_stat_mbx;
mailbox mem2scb_mbx;
mailbox mon2scb_mbx;

event test_started;
event test_finished;

// virtual amm_if #(
//   .ADDR_W ( 4 ),
//   .DATA_W ( 32 )
// ) amm_if_csr;

// virtual amm_if #(
//   .ADDR_W   ( AMM_ADDR_W  ),
//   .DATA_W   ( AMM_DATA_W  ),
//   .BURST_W  ( AMM_BURST_W )
// ) amm_if_mem;

function new(
  virtual amm_if #(
    .ADDR_W ( 4 ),
    .DATA_W ( 32 )
  ) amm_if_csr,
  virtual amm_if #(
    .ADDR_W   ( AMM_ADDR_W  ),
    .DATA_W   ( AMM_DATA_W  ),
    .BURST_W  ( AMM_BURST_W )
  ) amm_if_mem
);
  // this.amm_if_csr = amm_if_csr;
  // this.amm_if_mem = amm_if_mem;
  gen2driv_mbx      = new( 1 );
  gen2mem_mbx       = new();
  driv2scb_test_mbx = new();
  driv2scb_stat_mbx = new();
  mem2scb_mbx       = new();
  mon2scb_mbx       = new();

  gen   = new( gen2driv_mbx, gen2mem_mbx );
  driv  = new( amm_if_csr, gen2driv_mbx, driv2scb_test_mbx, driv2scb_stat_mbx, test_started, test_finished );
  mem   = new( amm_if_mem, gen2mem_mbx, mem2scb_mbx, test_started, test_finished );
  mon   = new( amm_if_mem, mon2scb_mbx, test_finished );
  scb   = new( driv2scb_test_mbx, driv2scb_stat_mbx, mem2scb_mbx, mon2scb_mbx );
endfunction

task automatic run();
  gen.run();
  driv.run();
  mem.run();
  mon.run();
  scb.test_amount = 3500;
  scb.run();
  wait( scb.test_amount == 0 );
endtask : run

endclass : environment