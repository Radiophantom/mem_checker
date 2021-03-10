`include "./src/class/environment.sv"

import rtl_settings_pkg::*;
import tb_settings_pkg::*;

`timescale 1 ps / 1 ps

module mem_checker_tb();

bit clk_mem;
bit clk_sys;
bit rst;

environment env;

always
  #( CLK_SYS_T / 2 ) clk_sys = ~clk_sys;

always
  #( CLK_MEM_T / 2 ) clk_mem = ~clk_mem;

amm_if #(
  .ADDR_W ( 4 ),
  .DATA_W ( 32 )
) amm_if_csr( clk_sys );

amm_if #(
  .ADDR_W   ( AMM_ADDR_W  ),
  .DATA_W   ( AMM_DATA_W  ),
  .BURST_W  ( AMM_BURST_W )
) amm_if_mem( clk_mem );

initial
  begin
    rst = 1'b1;
    #( CLK_SYS_T / 2 );
    rst = 1'b0;

    env = new( amm_if_csr, amm_if_mem );
    repeat( 10 )
      @( posedge amm_if_csr.clk );
    env.run();
  end

mem_checker mem_checker_inst(
  .rst_i      ( rst     ),
  .clk_sys_i  ( clk_sys ),
  .clk_mem_i  ( clk_mem ),

  .sys_read_i           ( amm_if_csr.read           ),
  .sys_write_i          ( amm_if_csr.write          ),
  .sys_address_i        ( amm_if_csr.address        ),
  .sys_writedata_i      ( amm_if_csr.writedata      ),
  .sys_readdatavalid_o  ( amm_if_csr.readdatavalid  ),
  .sys_readdata_o       ( amm_if_csr.readdata       ),

  .mem_readdatavalid_i  ( amm_if_mem.readdatavalid  ),
  .mem_readdata_i       ( amm_if_mem.readdata       ),

  .mem_waitrequest_i    ( amm_if_mem.waitrequest    ),

  .mem_address_o        ( amm_if_mem.address        ),
  .mem_read_o           ( amm_if_mem.read           ),
  .mem_write_o          ( amm_if_mem.write          ),
  .mem_writedata_o      ( amm_if_mem.writedata      ),
  .mem_burstcount_o     ( amm_if_mem.burstcount     ),
  .mem_byteenable_o     ( amm_if_mem.byteenable     )
);

endmodule : mem_checker_tb