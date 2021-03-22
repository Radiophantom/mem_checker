import rtl_settings_pkg::*;

module csr_block( 
  input                                                   rst_sys_i,
  input                                                   rst_mem_i,
  input                                                   clk_sys_i,
  input                                                   clk_mem_i,

  // Input Avalon-MM interface

  input                                                   read_i,
  input                                                   write_i,
  input                                        [3  : 0]   address_i,
  input                                        [31 : 0]   writedata_i,

  output logic                                            readdatavalid_o,
  output logic                                 [31 : 0]   readdata_o,

  // Output checker interface
  input                                                   test_finished_i, 
  input         [CSR_RD_REQ : CSR_TEST_RESULT ][31 : 0]   test_result_i,

  output logic                                            test_start_o,
  output logic  [CSR_SET_DATA : CSR_TEST_PARAM][31 : 0]   test_param_o 
);

//**********************************
// Variables declaration
//**********************************

logic                                 [2  : 0]  test_finished_reg;
logic                                           test_finished_stb;

logic                                 [2  : 0]  rst_start_bit_reg;
logic                                           rst_start_bit_stb;

logic                                 [2  : 0]  test_start_reg;
logic                                           test_start_stb;

logic                                           read_req;

logic                                 [31 : 0]  test_start_csr;
logic [CSR_SET_DATA : CSR_TEST_PARAM ][31 : 0]  test_param_csr;
logic [CSR_RD_REQ   : CSR_TEST_FINISH][31 : 0]  result_csr;
logic [CSR_RD_REQ   : CSR_TEST_START ][31 : 0]  read_csr;

//**********************************
// Test parameters CSR
//**********************************

// self-clear start bit after test already started
always_ff @( posedge clk_sys_i, posedge rst_sys_i )
  if( rst_sys_i )
    test_start_csr[0] <= 1'b0;
  else
    if( rst_start_bit_stb )
      test_start_csr[0] <= 1'b0;
    else
      if( write_i && ( address_i == CSR_TEST_START ) )
        test_start_csr[0] <= writedata_i[0];

always_ff @( posedge clk_sys_i )
  if( write_i )
    test_param_csr[address_i] <= writedata_i;

//**********************************
// Test result CSR
//**********************************

// self-clear finish bit after register was read
always_ff @( posedge clk_sys_i, posedge rst_sys_i )
  if( rst_sys_i )
    result_csr[CSR_TEST_FINISH][0] <= 1'b0;
  else
    if( test_finished_stb )
      result_csr[CSR_TEST_FINISH][0] <= 1'b1;
    else
      if( read_i && ( address_i == CSR_TEST_FINISH ) )
        result_csr[CSR_TEST_FINISH][0] <= 1'b0;

always_ff @( posedge clk_sys_i )
  if( test_finished_stb )
    result_csr[CSR_RD_REQ : CSR_TEST_RESULT] <= test_result_i;

//**********************************
// Avalon-MM read logic
//**********************************
    
always_ff @( posedge clk_sys_i, posedge rst_sys_i )
  if( rst_sys_i )
    readdatavalid_o <= 1'b0;
  else
    readdatavalid_o <= read_i;

always_ff @( posedge clk_sys_i )
  if( read_i )
    readdata_o <= read_csr[address_i];

//************************************
// Cross clock domain synchronization
//************************************

always_ff @( posedge clk_mem_i, posedge rst_mem_i )
  if( rst_mem_i )
    test_start_reg <= 3'( 0 );
  else
    test_start_reg <= { test_start_reg[1 : 0], test_start_csr[0] };

always_ff @( posedge clk_sys_i, posedge rst_sys_i )
  if( rst_sys_i )
    rst_start_bit_reg <= 3'( 0 );
  else
    rst_start_bit_reg <= { rst_start_bit_reg[1 : 0], test_start_reg[1] };

always_ff @( posedge clk_sys_i, posedge rst_sys_i )
  if( rst_sys_i )
    test_finished_reg <= 3'( 0 );
  else
    test_finished_reg <= { test_finished_reg[1 : 0], test_finished_i };

// edge detector strobes
assign test_start_stb     = ( test_start_reg   [1]  && ( !test_start_reg   [2] ) );
assign rst_start_bit_stb  = ( rst_start_bit_reg[1]  && ( !rst_start_bit_reg[2] ) );
assign test_finished_stb  = ( test_finished_reg[1]  && ( !test_finished_reg[2] ) );

// CSR space mapping
assign read_csr           = { result_csr, test_param_csr, test_start_csr };

assign test_start_o       = test_start_stb;
assign test_param_o       = test_param_csr;

endmodule : csr_block