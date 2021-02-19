import rtl_settings_pkg::*;

`include "../rtl/fifo.sv"

module compare_block(
  input                               clk_i,
  input                               rst_i,

  input                               start_test_i,

  input                               readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,

  input                               cmp_struct_en_i,
  input  cmp_struct_t                 cmp_struct_i,

  output logic                        err_check_o,
  output logic  [ADDR_W - 1 : 0]      err_addr_o,
  output logic  [7 : 0]               err_data_o,
  output logic  [7 : 0]               orig_data_o,

  output logic                        cmp_block_busy_o
);

fifo #(
  parameter int AWIDTH = 2
) cmp_storage (
  .clk_i    ( clk_i           ),
  .srst_i   ( start_test_i    ),

  .wrreq_i  ( cmp_struct_en_i ),
  .data_i   ( cmp_struct_i    ),

  .rdreq_i  ( get_cmp_struct  ),
  .q_o      ( storage_struct  ),

  .empty_o  ( fifo_empty      )
);

logic           get_cmp_struct;
cmp_struct_t    storage_struct;

logic           fifo_empty;

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

cmp_struct_t              storage_struct, cur_struct;
logic                     storage_valid;
logic                     stop_checker_flag;
logic                     check_complete_stb;
logic [DATA_B_W - 1 : 0]  check_vector;
logic                     in_process;
logic [15 : 0]            word_cnt;
logic                     err_check_result, data_gen_bit, load_stb;
logic                     last_word;
logic [ADDR_W - 1 : 0]    check_addr_cnt;
logic [ADDR_W - 1 : 0]    check_addr_reg;
logic                     readdatavalid_dly;
logic [7 : 0]             data_ptrn_reg;
logic [DATA_B_W - 1 : 0]  check_ptrn_vec;
logic [7 : 0]             data_gen_reg;

logic [AMM_DATA_W - 1 : 0] readdata_dly;
logic [7 : 0] check_data_ptrn;

always_comb
  if( !in_process )
    get_cmp_struct = 1'b1;
  else
    get_cmp_struct = ( readdatavalid_i && last_word );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    in_process <= 1'b0;
  else
    if( !in_process )
      in_process <= get_cmp_struct;
    else
      if( get_cmp_struct )
        in_process <= 1'b1;
      else
        in_process <= 1'b0;

logic [AMM_BURST_W - 2 : 0] word_cnt;
logic                       last_word;

always_ff @( posedge clk_i )
  if( load_stb )
    word_cnt <= storage_struct.words_count;
  else
    if( readdatavalid_i )
      word_cnt <= word_cnt - 1'b1;

assign last_word = ( word_cnt == 0 );

always_ff @( posedge clk_i )
  load_stb <= ( get_cmp_struct && ( !fifo_empty ) );

always_ff @( posedge clk_i )
  if( load_stb )
    cur_pkt <= storage_pkt;

always_ff @( posedge clk_i )
  if( load_stb )
    check_ptrn <= byteenable_ptrn( 1'b1, storage_struct.start_off, ( storage_struct.words_count == 0 ), storage_struct.end_off );
  else
    if( readdatavalid_i )
      check_ptrn <= byteenable_ptrn( 1'b0, cur_struct.start_off, last_word, cur_struct.end_off );

always_ff @( posedge clk_i )
  if( load_stb )
    data_ptrn <= storage_struct.data_ptrn;
  else
    if( cur_struct.data_mode == RND_DATA )
      if( readdatavalid_i )
        data_ptrn <= { data_ptrn[6:0], data_gen_bit };

always_ff @( posedge clk_i )
  readdatavalid_dly <= readdatavalid_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    readdata_dly <= readdata_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_vector <= check_ptrn_func( check_ptrn, data_ptrn, readdata_i );

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_data_ptrn <= data_ptrn;

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
  if( load_stb )
    if( ADDR_TYPE == "BYTE" )
      check_addr_cnt <= storage_struct.start_addr[ADDR_W - 1 : ADDR_B_W];
    else
      if( ADDR_TYPE == "WORD" )
        check_addr_cnt <= storage_struct.start_addr;
  else
    if( readdatavalid_i )
      check_addr_cnt <= check_addr_cnt + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    stop_checker_flag <= 1'b0;
  else
    if( start_test_i )
      stop_checker_flag <= 1'b0;
    else
      if( readdatavalid_dly && err_check_result )
        stop_checker_flag <= 1'b1;

always_ff @( posedge clk_i )
  err_check_o <= ( readdatavalid_dly && err_check_result );

always_ff @( posedge clk_i )
  if( readdatavalid_dly && err_check_result )
    err_addr_o <= { check_addr_reg, err_byte_num_func( check_vector ) };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_block_busy_o <= 1'b0;
  else
    if( cmp_struct_en_i )
      cmp_block_busy_o <= 1'b1;
    else
      if( ( !in_process ) && fifo_empty )
        cmp_block_busy_o <= 1'b0;
      else
        if( err_check_result )
          cmp_block_busy_o <= 1'b0;

assign err_check_result   = ( &check_vector );
assign data_gen_bit       = ( data_ptrn_reg[6] ^ data_ptrn_reg[1] ^ data_ptrn_reg[0] );

assign check_complete_stb = ( last_word && readdatavalid_i );
assign load_stb   = ( !in_process || check_complete_stb ) ? ( storage_valid ) : 1'b0;

endmodule : compare_block
