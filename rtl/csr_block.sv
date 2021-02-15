import settings_pkg::*;

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
  input                           wr_result_i, 
  input                           test_result_i,

  input         [ADDR_W - 1 : 0]  err_addr_i,
  input         [7 : 0]           err_data_i,
  input         [7 : 0]           exp_data_i,

  input         [15 : 0]          rd_req_cnt_i,
  input         [15 : 0]          min_delay_i,
  input         [15 : 0]          max_delay_i,
  input         [31 : 0]          sum_delay_i,

  input         [31 : 0]          rd_ticks_i,
  input         [31 : 0]          rd_words_i,

  input         [31 : 0]          wr_ticks_i,
  input         [31 : 0]          wr_units_i,

  output logic                    start_test_o,
  output logic  [3 : 1][31 : 0]   test_param_reg_o 
);

logic [2 : 0]           wr_result_sync_reg;
logic                   wr_result_stb;
logic [2 : 0]           rst_start_test_sync_reg;
logic                   rst_start_bit;
logic [2 : 0]           start_test_sync_reg;

logic [14 : 4][31 : 0]  csr_reg;
logic [3  : 0][31 : 0]  wr_csr_reg;
logic [14 : 0][31 : 0]  rd_csr_reg;

always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    csr_reg[4][0] <= 1'b0;
  else
    if( wr_result_stb )
      csr_reg[4][0] <= 1'b1;
    else
      if( read_i && ( address_i == 4 ) )
        csr_reg[4][0] <= 1'b0;

always_ff @( posedge clk_sys_i )
  if( wr_result_stb )
    begin
      csr_reg[5]  <= test_result_i;
      csr_reg[6]  <= err_addr_i;
      csr_reg[7]  <= { exp_data_i, err_data_i };
      csr_reg[8]  <= wr_ticks_i;
      csr_reg[9]  <= wr_units_i;
      csr_reg[10] <= rd_ticks_i;
      csr_reg[11] <= rd_words_i;
      csr_reg[12] <= { min_delay_i, max_delay_i };
      csr_reg[13] <= sum_delay_i;
      csr_reg[14] <= rd_req_cnt_i;
    end
    
always_ff @( posedge clk_sys_i, posedge rst_i )
  if( rst_i )
    wr_csr_reg[0][0] <= 1'b0;
  else
    if( address_i == 0 )
      begin
        if( rst_start_bit )
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
    wr_result_sync_reg <= 3'd0;
  else
    wr_result_sync_reg <= { wr_result_sync_reg[1:0], wr_result_i };

assign wr_result_stb    = ( wr_result_sync_reg[1]       && !wr_result_sync_reg[2]       );
assign start_test_o     = ( start_test_sync_reg[1]      && !start_test_sync_reg[2]      );
assign rst_start_bit    = ( rst_start_test_sync_reg[1]  && !rst_start_test_sync_reg[2]  );

assign rd_csr_reg       = { csr_reg, wr_csr_reg };

assign test_param_reg_o = wr_csr_reg[3:1];

endmodule : csr_block
