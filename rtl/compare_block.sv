import rtl_settings_pkg::*;

module compare_block(
  input                               clk_i,
  input                               rst_i,

  input                               start_test_i,

  // Avalon-MM interface
  input                               readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,

  input                               cmp_pkt_en_i,
  input  cmp_pkt_t                    cmp_pkt_i,

  output logic                        err_check_o,
  output logic  [ADDR_W - 1 : 0]      err_addr_o,
  output logic  [7 : 0]               err_data_o,
  output logic  [7 : 0]               orig_data_o,

  output logic                        cmp_block_busy_o
);

function automatic logic [DATA_B_W - 1 : 0] check_ptrn_func(
  logic [DATA_B_W - 1 : 0]    check_ptrn,
  logic [7 : 0]               data_ptrn,
  logic [AMM_DATA_W - 1 : 0]  readdata
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_ptrn[i] )
      check_ptrn_func[i] = ( data_ptrn != readdata[7 + i*8 -: 8] );
    else
      check_ptrn_func[i] = 1'b0;
endfunction : check_ptrn_func

function automatic logic [ADDR_B_W - 1 : 0] err_byte_num_func(
  logic [DATA_B_W - 1 : 0] check_ptrn
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_ptrn[i] )
      return( i );
  return( 0 );
endfunction : err_byte_num_func

cmp_pkt_t                 storage_pkt, cur_pkt;
logic                     storage_valid;
logic                     stop_checker_flg;
logic                     check_complete_stb;
logic [DATA_B_W - 1 : 0]  check_vector;
logic                     in_process_flg;
logic [15 : 0]            word_cnt;
logic                     err_check_result, data_gen_bit, load_checker_stb;
logic                     last_word_flg;
logic [ADDR_W - 1 : 0]    check_addr_cnt;
logic [ADDR_W - 1 : 0]    check_addr_reg;
logic                     readdatavalid_dly;
logic [7 : 0]             data_ptrn_reg;
logic [DATA_B_W - 1 : 0]  check_ptrn_vec;
logic [7 : 0]             data_gen_reg;

logic [AMM_DATA_W - 1 : 0] readdata_dly;
logic [7 : 0] check_data_ptrn;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid <= 1'b0;
  else
    if( stop_checker_flg )
      storage_valid <= 1'b0;
    else
      if( cmp_pkt_en_i )
        storage_valid <= 1'b1;
      else
        if( load_checker_stb )
          storage_valid <= 1'b0;

always_ff @( posedge clk_i )
  if( cmp_pkt_en_i )
    storage_pkt <= cmp_pkt_i;

always_ff @( posedge clk_i )
  if( load_checker_stb )
    cur_pkt <= storage_pkt;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    in_process_flg <= 1'b0;
  else
    if( load_checker_stb )
      in_process_flg <= 1'b1;
    else
      if( check_complete_stb )
        in_process_flg <= 1'b0;

always_ff @( posedge clk_i )
  if( load_checker_stb )
    word_cnt <= storage_pkt.word_count;
  else
    if( readdatavalid_i )
      word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( load_checker_stb )
    last_word_flg <= ( storage_pkt.word_count == 1 );
  else
    if( readdatavalid_i )
      last_word_flg <= ( word_cnt == 2 );

always_ff @( posedge clk_i )
  if( load_checker_stb )
    begin
      if( storage_pkt.word_count == 1 )
        check_ptrn_vec <= storage_pkt.middle_mask;
      else
        check_ptrn_vec <= storage_pkt.start_mask;
    end
  else
    if( readdatavalid_i )
      if( word_cnt == 2 )
        check_ptrn_vec <= cur_pkt.end_mask;
      else
        check_ptrn_vec <= '1;

always_ff @( posedge clk_i )
  readdatavalid_dly <= readdatavalid_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    readdata_dly <= readdata_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_data_ptrn <= data_ptrn_reg;

always_ff @( posedge clk_i )
  if( readdatavalid_dly && err_check_result )
    err_data_o <= readdata_dly[7 + 8 * ( err_byte_num_func( check_vector ) ) -: 8];

always_ff @( posedge clk_i )
  if( readdatavalid_dly && err_check_result )
    orig_data_o <= check_data_ptrn;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_addr_reg <= check_addr_cnt;

always_ff @( posedge clk_i )
  if( load_checker_stb )
    begin
      if( ADDR_TYPE == "BYTE" )
        check_addr_cnt <= storage_pkt.word_addr[ADDR_W - 1 : ADDR_B_W];
      else
        if( ADDR_TYPE == "WORD" )
          check_addr_cnt <= storage_pkt.word_addr;
    end
  else
    if( readdatavalid_i )
      check_addr_cnt <= check_addr_cnt + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    stop_checker_flg <= 1'b0;
  else
    if( start_test_i )
      stop_checker_flg <= 1'b0;
    else
      if( readdatavalid_dly && err_check_result )
        stop_checker_flg <= 1'b1;

always_ff @( posedge clk_i )
  if( load_checker_stb )
    data_ptrn_reg <= storage_pkt.data_ptrn;
  else
    if( readdatavalid_i && cur_pkt.data_ptrn_mode )
        data_ptrn_reg <= { data_ptrn_reg[6:0], data_gen_bit };

always_ff @( posedge clk_i )
  err_check_o <= ( readdatavalid_dly && err_check_result );

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_vector <= check_ptrn_func( check_ptrn_vec, data_ptrn_reg, readdata_i );

always_ff @( posedge clk_i )
  if( readdatavalid_dly && err_check_result )
    err_addr_o <= { check_addr_reg, err_byte_num_func( check_vector ) };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_block_busy_o <= 1'b0;
  else
    cmp_block_busy_o <= ( storage_valid || in_process_flg );

assign err_check_result   = ( &check_vector );
assign data_gen_bit       = ( data_ptrn_reg[6] ^ data_ptrn_reg[1] ^ data_ptrn_reg[0] );

assign check_complete_stb = ( last_word_flg && readdatavalid_i );
assign load_checker_stb   = ( !in_process_flg || check_complete_stb ) ? ( storage_valid ) : 1'b0;

endmodule : compare_block
