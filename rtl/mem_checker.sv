import rtl_settings_pkg::*;

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

logic [15 : 0][31 : 0]  csr_registers;

logic wr_result;
logic test_result;

logic err_check;
logic cmp_block_busy;
logic trans_block_busy;
logic meas_block_busy;
logic cmd_accepted;
logic cmp_pkt_en;

logic start_test;
logic op_valid;

csr_block csr_block_inst( 
  .rst_i            ( rst_i                 ),
  .clk_sys_i        ( clk_sys_i             ),
  .clk_mem_i        ( clk_mem_i             ),

  .read_i           ( sys_read_i       ),
  .write_i          ( sys_write_i      ),
  .address_i        ( sys_address_i    ),
  .writedata_i      ( sys_writedata_i  ),
  .readdata_o       ( sys_readdata_o   ),

  .wr_result_i      ( wr_result        ),
  .test_result_i    ( test_result      ),

  .err_addr_i       ( csr_registers[6]            ),
  .err_data_i       ( csr_registers[7][7 : 0]     ),
  .orig_data_i      ( csr_registers[7][15 : 8]    ),
  .wr_ticks_i       ( csr_registers[8]            ),
  .wr_units_i       ( csr_registers[9]            ),
  .rd_ticks_i       ( csr_registers[10]           ),
  .rd_words_i       ( csr_registers[11]           ),
  .min_max_delay_i  ( csr_registers[12]           ),
  .sum_delay_i      ( csr_registers[13]           ),
  .rd_req_cnt_i     ( csr_registers[14]           ),

  .start_test_o     ( start_test                  ),
  .test_param_reg_o ( csr_registers[3 : 1]        ) 
);

control_block control_block_inst(
  .rst_i              ( rst_i                 ),
  .clk_i              ( clk_mem_i             ),

  .start_test_i       ( start_test            ),

  .err_check_i        ( err_check             ),

  .cmp_block_busy_i   ( cmp_block_busy        ),
  .meas_block_busy_i  ( meas_block_busy       ),
  .trans_block_busy_i ( trans_block_busy      ),

  .test_param_reg_i   ( csr_registers[3 : 1]  ),

  .cmd_accept_ready_i ( cmd_accepted          ),

  .wr_result_o        ( wr_result             ),
  .test_result_o      ( test_result           ),

  .op_valid_o         ( op_valid              ),
  .op_pkt_o           ( op_pkt                )
);

trans_pkt_t op_pkt;
cmp_pkt_t cmp_pkt;

transmitter_block transmitter_block_inst( 
  .rst_i              ( rst_i                 ),
  .clk_i              ( clk_mem_i             ),

  .op_valid_i         ( op_valid              ),
  .op_pkt_i           ( op_pkt                ),

  .test_param_reg_i   ( csr_registers[3 : 1]  ),

  .cmd_accept_ready_o ( cmd_accepted          ),
  .trans_block_busy_o ( trans_block_busy      ),

  .error_check_i      ( err_check             ),

  .cmp_pkt_en_o       ( cmp_pkt_en            ),
  .cmp_pkt_o          ( cmp_pkt               ),

  .readdatavalid_i    ( mem_readdatavalid_i ),
  .readdata_i         ( mem_readdata_i      ),
  .waitrequest_i      ( mem_waitrequest_i   ),

  .address_o          ( mem_address_o       ),
  .read_o             ( mem_read_o          ),
  .write_o            ( mem_write_o         ),
  .writedata_o        ( mem_writedata_o     ),
  .burstcount_o       ( mem_burstcount_o    ),
  .byteenable_o       ( mem_byteenable_o    )
);

compare_block compare_block_inst(
  .rst_i            ( rst_i                     ),
  .clk_i            ( clk_mem_i                 ),

  .start_test_i     ( start_test                ),

  .readdatavalid_i  ( mem_readdatavalid_i       ),
  .readdata_i       ( mem_readdata_i            ),

  .cmp_pkt_en_i     ( cmp_pkt_en                ),
  .cmp_pkt_i        ( cmp_pkt                   ),

  .err_check_o      ( err_check                 ),
  .err_addr_o       ( csr_registers[6]          ),
  .err_data_o       ( csr_registers[7][7 : 0]   ),
  .orig_data_o      ( csr_registers[7][15 : 8]  ),

  .cmp_block_busy_o ( cmp_block_busy            )
);

measure_block measure_block_inst( 
  .rst_i              ( rst_i               ),
  .clk_i              ( clk_mem_i           ),

  .readdatavalid_i    ( mem_readdatavalid_i ),
  .waitrequest_i      ( mem_waitrequest_i   ),

  .read_i             ( mem_read_o          ),
  .write_i            ( mem_write_o         ),
  .burstcount_i       ( mem_burstcount_o    ),
  .byteenable_i       ( mem_byteenable_o    ),

  .start_test_i       ( start_test          ),

  .meas_block_busy_o  ( meas_block_busy     ),

  .wr_ticks_o         ( csr_registers[8]    ),
  .wr_units_o         ( csr_registers[9]    ),
  .rd_ticks_o         ( csr_registers[10]   ),
  .rd_words_o         ( csr_registers[11]   ),
  .min_max_delay_o    ( csr_registers[12]   ),
  .sum_delay_o        ( csr_registers[13]   ),
  .rd_req_amount_o    ( csr_registers[14]   )
);

endmodule : mem_checker
