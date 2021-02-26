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

logic test_finish;
logic test_result;

logic cmp_error;
logic cmp_busy;
logic trans_busy;
logic meas_busy;

logic start_test;

csr_block csr_block_inst( 
  .rst_i            ( rst_i            ),
  .clk_sys_i        ( clk_sys_i        ),
  .clk_mem_i        ( clk_mem_i        ),

  .read_i           ( sys_read_i       ),
  .write_i          ( sys_write_i      ),
  .address_i        ( sys_address_i    ),
  .writedata_i      ( sys_writedata_i  ),
  .readdata_o       ( sys_readdata_o   ),

  .test_finished_i  ( test_finish           ),
  .test_result_i    ( csr_registers[14 : 5] ),

  .start_test_o     ( start_test            ),
  .test_param_o     ( csr_registers[3 : 1]  ) 
);

assign csr_registers[5][0] = test_result;

control_block control_block_inst(
  .rst_i            ( rst_i                 ),
  .clk_i            ( clk_mem_i             ),
                                              
  .start_test_i     ( start_test            ),
  .test_param_i     ( csr_registers[3 : 1]  ),
                                              
  .test_finished_o  ( test_finish           ),
  .test_result_o    ( test_result           ),
                                              
  .cmp_error_i      ( cmp_error             ),
  .cmp_busy_i       ( cmp_busy              ),
                                              
  .meas_busy_i      ( meas_busy             ),
                                              
  .trans_process_i  ( trans_process         ),
  .trans_busy_i     ( trans_busy            ),
                                              
  .trans_valid_o    ( trans_valid           ),
  .trans_addr_o     ( trans_addr            ),
  .trans_type_o     ( trans_type            )
);

cmp_struct_t      cmp_struct;
logic             cmp_en;

logic                   trans_valid;
logic [ADDR_W - 1 : 0]  trans_addr;
logic                   trans_type;

logic                   trans_process;

transmitter_block transmitter_block_inst( 
  .rst_i              ( rst_i                 ),
  .clk_i              ( clk_mem_i             ),
                                                 
  .test_param_i       ( csr_registers[3 : 1]  ),
                                                 
  .trans_valid_i      ( trans_valid           ),
  .trans_addr_i       ( trans_addr            ),
  .trans_type_i       ( trans_type            ),
                                                 
  .trans_process_o    ( trans_process         ),
  .trans_busy_o       ( trans_busy            ),
                                                 
  .cmp_error_i        ( cmp_error             ),
                                                 
  .cmp_en_o           ( cmp_en                ),
  .cmp_struct_o       ( cmp_struct            ),

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
                                                  
  .cmp_en_i         ( cmp_en                    ),
  .cmp_struct_i     ( cmp_struct                ),
                                                  
  .cmp_error_o      ( cmp_error                 ),
  .err_addr_o       ( csr_registers[6]          ),
  .err_data_o       ( csr_registers[7]          ),
                                                  
  .cmp_busy_o       ( cmp_busy                  )
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

  .meas_block_busy_o  ( meas_busy     ),

  .wr_ticks_o         ( csr_registers[8]    ),
  .wr_units_o         ( csr_registers[9]    ),
  .rd_ticks_o         ( csr_registers[10]   ),
  .rd_words_o         ( csr_registers[11]   ),
  .min_max_delay_o    ( csr_registers[12]   ),
  .sum_delay_o        ( csr_registers[13]   ),
  .rd_req_amount_o    ( csr_registers[14]   )
);

endmodule : mem_checker
