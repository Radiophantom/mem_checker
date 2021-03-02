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

logic [CSR_RD_REQ : CSR_TEST_START][31 : 0]  csr_registers;

logic test_finish;
logic test_result;

logic cmp_error;
logic cmp_busy;
logic trans_busy;
logic meas_busy;

logic test_start;

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
  .test_result_i    ( csr_registers[CSR_RD_REQ : CSR_TEST_RESULT] ),

  .test_start_o     ( test_start            ),
  .test_param_o     ( csr_registers[CSR_SET_DATA : CSR_TEST_PARAM]  ) 
);

assign csr_registers[CSR_TEST_RESULT][0] = test_result;

control_block control_block_inst(
  .rst_i            ( rst_i                 ),
  .clk_i            ( clk_mem_i             ),
                                              
  .test_start_i     ( test_start            ),
  .test_param_i     ( csr_registers[CSR_SET_ADDR : CSR_TEST_PARAM] ),
                                              
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
                                                 
  .test_param_i       ( csr_registers[CSR_SET_DATA : CSR_TEST_PARAM]  ),
                                                 
  .trans_valid_i      ( trans_valid           ),
  .trans_addr_i       ( trans_addr            ),
  .trans_type_i       ( trans_type            ),
                                                 
  .trans_ready_o      ( trans_process         ),
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
                                                 
  .test_start_i     ( test_start                ),
                                                  
  .readdatavalid_i  ( mem_readdatavalid_i       ),
  .readdata_i       ( mem_readdata_i            ),
                                                  
  .cmp_en_i         ( cmp_en                    ),
  .cmp_struct_i     ( cmp_struct                ),
                                                  
  .cmp_error_o      ( cmp_error                 ),
  .err_result_o     ( csr_registers[CSR_ERR_DATA : CSR_ERR_ADDR] ),
                                                  
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

  .test_start_i       ( test_start          ),

  .meas_busy_o  ( meas_busy     ),

  .meas_result_o      ( csr_registers[CSR_RD_REQ : CSR_WR_TICKS] )
);

endmodule : mem_checker
