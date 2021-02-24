import rtl_settings_pkg::*;

module csr_block( 
  input                           rst_i,
  input                           clk_sys_i,
  input                           clk_mem_i,

  // Input Avalon-MM interface

  input                           read_i,                 // 0 cycle delay to readdata | read_i     -> _/TTT\_
  input                           write_i,                //                           | readdata_o -> ______/TTT\_
  input         [3  : 0]          address_i,
  input         [31 : 0]          writedata_i,

  output  logic [31 : 0]          readdata_o,

  // Output checker interface
  input                           test_finished_i, 
  input         [14 : 5][31 : 0]  test_result_i,

  output logic                    start_test_o,
  output logic  [3  : 1][31 : 0]  test_param_o 
);

logic [2  : 0]          test_finished_sync_reg;
logic                   test_finished_stb;
logic [2  : 0]          rst_start_test_sync_reg;
logic                   rst_start_bit_stb;
logic [2  : 0]          start_test_sync_reg;

logic [14 : 4][31 : 0]  csr_reg;

logic [3  : 0][31 : 0]  wr_csr_reg;
logic [14 : 0][31 : 0]  rd_csr_reg;

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    csr_reg[4][0] <= 1'b0;
  else
    if( test_finished_stb )
      csr_reg[4][0] <= 1'b1;
    else
      if( read_i && ( address_i == 4 ) )
        csr_reg[4][0] <= 1'b0;

always_ff @( posedge clk_sys_i )
  if( test_finished_stb )
    begin
      csr_reg[CSR_TEST_RESULT ] <= test_result_i[CSR_TEST_RESULT ];
      csr_reg[CSR_ERR_ADDR    ] <= test_result_i[CSR_ERR_ADDR    ];
      csr_reg[CSR_ERR_DATA    ] <= test_result_i[CSR_ERR_DATA    ];
      csr_reg[CSR_WR_TICKS    ] <= test_result_i[CSR_WR_TICKS    ];
      csr_reg[CSR_WR_UNITS    ] <= test_result_i[CSR_WR_UNITS    ];
      csr_reg[CSR_RD_TICKS    ] <= test_result_i[CSR_RD_TICKS    ];
      csr_reg[CSR_RD_WORDS    ] <= test_result_i[CSR_RD_WORDS    ];
      csr_reg[CSR_MIN_MAX_DEL ] <= test_result_i[CSR_MIN_MAX_DEL ];
      csr_reg[CSR_SUM_DEL     ] <= test_result_i[CSR_SUM_DEL     ];
      csr_reg[CSR_RD_REQ      ] <= test_result_i[CSR_RD_REQ      ];
    end
    
always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    wr_csr_reg[0][0] <= 1'b0;
  else
    if( address_i == 0 )
      begin
        if( rst_start_bit_stb )
          wr_csr_reg[0][0] <= 1'b0;
        else
          if( write_i )
            wr_csr_reg[0][0] <= writedata_i[0];
      end
    else
      if( write_i )
        wr_csr_reg[address_i] <= writedata_i;

always_ff @( posedge clk_sys_i )
  if( read_i )
    readdata_o <= rd_csr_reg[address_i];

always_ff @( posedge clk_mem_i, posedge rst_i )
  if( rst_i )
    start_test_sync_reg <= 3'd0;
  else
    start_test_sync_reg <= { start_test_sync_reg[1:0], wr_csr_reg[0][0] };

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    rst_start_test_sync_reg <= 3'd0;
  else
    rst_start_test_sync_reg <= { rst_start_test_sync_reg[1:0], start_test_o };

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    test_finished_sync_reg <= 3'd0;
  else
    test_finished_sync_reg <= { test_finished_sync_reg[1:0], test_finished_i };

assign test_finished_stb  = ( test_finished_sync_reg[1]   && !test_finished_sync_reg[2]   );
assign start_test_o       = ( start_test_sync_reg[1]      && !start_test_sync_reg[2]      );
assign rst_start_bit_stb  = ( rst_start_test_sync_reg[1]  && !rst_start_test_sync_reg[2]  );

assign rd_csr_reg       = { csr_reg, wr_csr_reg };

assign test_param_o = wr_csr_reg[3:1];

endmodule : csr_block
