`include "../src/interface/amm_if.sv"

import settings_pkg::*;

module mem_checker(
  input                               rst_i,
  input                               clk_sys_i,
  input                               clk_mem_i,

  // Avalon-MM input interface

  input                               sys_read_i,
  input                               sys_write_i,
  input         [3  : 0]              sys_address_i,
  input         [31 : 0]              sys_writedata_i,

  output  logic [31 : 0]              sys_readdata_o,
  
  // Avalon-MM output interface
  input                               mem_readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  mem_readdata_i,

  input                               mem_waitrequest_i,

  output logic  [AMM_ADDR_W - 1 : 0]  mem_address_o,
  output logic                        mem_read_o,
  output logic                        mem_write_o,
  output logic  [AMM_DATA_W - 1 : 0]  mem_writedata_o,
  output logic  [AMM_BURST_W - 1 : 0] mem_burstcount_o,
  output logic  [DATA_B_W - 1 : 0]    mem_byteenable_o
);

amm_if.master_lite  amm_master( clk_sys_i );
amm_if.slave        amm_slave ( clk_sys_i );

logic [15 : 4][31 : 0]  csr_registers;
logic [3 : 1][31 : 0]   test_param;

logic wr_result;
logic test_result;

csr_block_inst csr_block( 
  .rst_i            ( rst_i                 ),
  .clk_sys_i        ( clk_sys_i             ),
  .clk_mem_i        ( clk_mem_i             ),

  .read_i           ( amm_master.read       ),
  .write_i          ( amm_master.write      ),
  .address_i        ( amm_master.address    ),
  .writedata_i      ( amm_master.writedata  ),
  .readdata_o       ( amm_master.readdata   ),

  .wr_result_i      ( wr_result                   ),
  .test_result_i    ( test_result                 ),

  .err_addr_i       ( csr_registers[6]            ),
  .err_data_i       ( csr_registers[7][7 : 0]     ),
  .exp_data_i       ( csr_registers[7][15 : 8]    ),
  .rd_req_cnt_i     ( csr_registers[14]           ),
  .min_delay_i      ( csr_registers[12][31 : 16]  ),
  .max_delay_i      ( csr_registers[12][15 : 0]   ),
  .sum_delay_i      ( csr_registers[13]           ),
  .rd_ticks_i       ( csr_registers[10]           ),
  .rd_words_i       ( csr_registers[11]           ),
  .wr_ticks_i       ( csr_registers[18]           ),
  .wr_units_i       ( csr_registers[19]           ),

  .start_test_o     ( start_test                  ),
  .test_param_reg_o ( test_param                  ) 
);

ctrl_block_inst control_block(
  .rst_i              ( rst_i ),
  .clk_i              ( clk_mem_i ),

  .start_test_i       ( start_test ),

  .err_check_i        ( err_check ),

  .cmp_block_busy_i   ( cmp_block_busy ),
  .meas_block_busy_i  ( meas_block_busy),
  .trans_block_busy_i ( trans_block_busy),

  .test_param_reg_i   ( test_param[3 : 1] ),

  .cmd_accept_ready_i ( cmd_accepted ),

  .wr_result_o        ( wr_result ),

  .op_valid_o         ( op_valid ),
  .op_pkt_o           ( op_pkt )
);

trans_struct_t op_pkt;
logic op_valid;

cmp_struct_t cmp_pkt;
logic cmp_pkt;

trans_block_inst transmitter_block( 
  .rst_i              ( rst_i ),
  .clk_i              ( clk_mem_i ),

  .op_valid_i         ( op_valid ),
  .op_pkt_i           ( op_pkt ),

  .test_param_reg_i   ( test_param[3 : 1] ),

  .cmd_accept_ready_o ( cmd_accepted ),
  .trans_block_busy_o ( trans_block_busy ),

  .error_check_i      ( err_check ),

  .cmp_pkt_en_o       ( cmp_pkt_en ),
  .cmp_pkt_o          ( cmp_pkt ),

  .readdatavalid_i    ( amm_slave.readdatavalid ),
  .readdata_i         ( amm_slave.readdata      ),
  .waitrequest_i      ( amm_slave.waitrequest   ),

  .address_o          ( amm_slave.address       ),
  .read_o             ( amm_slave.read          ),
  .write_o            ( amm_slave.write         ),
  .writedata_o        ( amm_slave.writedata     ),
  .burstcount_o       ( amm_slave.burstcount    ),
  .byteenable_o       ( amm_slave.byteenable    )
);

cmp_block_inst compare_block(
  .rst_i            ( rst_i             ),
  .clk_i            ( clk_mem_i         ),

  .start_test_i     ( start_test_i      ),


  .readdatavalid_i  ( readdatavalid_i   ),
  .readdata_i       ( readdata_i        ),


  .cmp_pkt_en_i     ( cmp_pkt_en_i      ),
  .cmp_pkt_i        ( cmp_pkt_i         ),


  .error_check_o    ( error_check_o     ),
  .check_err_addr_o ( check_err_addr_o  ),

  .cmp_block_busy_o ( cmp_block_busy_o  )
);

amm_if.slave_mon amm_slave_mon;

meas_block_inst measure_block( 
  .rst_i                      ( rst_i                       ),
  .clk_i                      ( clk_mem_i                   ),

  .readdatavalid_i            ( amm_slave_mon.readdatavalid ),
  .waitrequest_i              ( amm_slave_mon.waitrequest   ),

  .read_i                     ( amm_slave_mon.read          ),
  .write_i                    ( amm_slave_mon.write         ),
  .burstcount_i               ( amm_slave_mon.burstcount    ),
  .byteenable_i               ( amm_slave_mon.byteenable    ),

  .start_test_i               ( start_test ),

  .trans_block_busy_o         ( trans_block_busy ),

  .sum_delay_o                ( csr_registers[13] ),
  .min_delay_o                ( csr_registers[12][31 : 16] ),
  .max_delay_o                ( csr_registers[12][15 : 0]  ),
  .read_ticks_o               ( csr_registers[10] ),
  .read_words_count_o         ( csr_registers[11] ),

  .write_ticks_o              ( csr_registers[18] ),
  .write_units_o              ( csr_registers[19] ),

  .rd_req_cnt_o               ( csr_registers[14] ),

  .start_test_o               ( start_test        ),
  .test_param_reg_o           ( test_param[3 : 1] ) 
);

endmodule : mem_checker
