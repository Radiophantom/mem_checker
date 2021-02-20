import rtl_settings_pkg::*;

//`include "../rtl/fifo.sv"

module compare_block(
  input                               clk_i,
  input                               rst_i,

  input                               start_test_i,

  // AMM interface
  input                               readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,

  // Transmitter interface
  input                               cmp_en_i,
  input  cmp_struct_t                 cmp_struct_i,

  // Error interface
  output logic                        cmp_error_o,
  output logic  [31 : 0]              err_addr_o,
  output logic  [7 : 0]               err_data_o,
  output logic  [7 : 0]               orig_data_o,

  output logic                        cmp_busy_o
);

fifo #(
  .AWIDTH   ( 2               )
) cmp_storage (
  .clk_i    ( clk_i           ),
  .srst_i   ( start_test_i    ),

  .wrreq_i  ( cmp_en_i        ),
  .data_i   ( cmp_struct_i    ),

  .rdreq_i  ( rd_storage  ),
  .q_o      ( storage_struct  ),

  .empty_o  ( storage_empty   )
);

logic           storage_empty;

cmp_struct_t              storage_struct;
cmp_struct_t              cur_struct;

logic                     storage_valid;
logic                     stop_checker;

logic                       rd_storage;
logic [DATA_B_W - 1 : 0]    check_vector_result;
logic                       in_process;

logic                     check_error;
logic                     data_gen_bit;
logic                     load_stb;
 
logic [DATA_B_W - 1 : 0]  check_ptrn;
logic [ADDR_W - 1 : 0]    cur_check_addr;
logic [7 : 0]             data_ptrn;
logic [DATA_B_W - 1 : 0]  check_ptrn_vec;
logic [7 : 0]             data_gen_reg;

logic                       readdatavalid_delayed;
logic [AMM_DATA_W - 1 : 0]  readdata_delayed;

logic [7 : 0]               check_data_ptrn;

logic [AMM_BURST_W - 2 : 0] word_cnt;
logic                       last_word;

always_comb
  if( !in_process )
    rd_storage = 1'b1;
  else
    rd_storage = ( readdatavalid_i && last_word );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    in_process <= 1'b0;
  else
    if( !in_process )
      in_process <= ( !storage_empty );
    else
      if( readdatavalid_i && last_word )
        if( !storage_empty )
          in_process <= 1'b1;
        else
          in_process <= 1'b0;

always_ff @( posedge clk_i )
  if( load_stb )
    word_cnt <= storage_struct.words_count;
  else
    if( readdatavalid_i )
      word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( load_stb )
    last_word <= ( word_cnt == 0 );
  else
    if( readdatavalid_i )
      last_word <= ( word_cnt == 1 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_stb <= 1'b0;
  else
    load_stb <= ( rd_storage && ( !storage_empty ) );

always_ff @( posedge clk_i )
  if( load_stb )
    cur_struct <= storage_struct;

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
  readdatavalid_delayed <= readdatavalid_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    readdata_delayed <= readdata_i;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_vector_result <= check_vector( check_ptrn, data_ptrn, readdata_i );

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    check_data_ptrn <= data_ptrn;

always_ff @( posedge clk_i )
  if( check_error )
    err_data_o <= readdata_delayed[7 + 8 * ( err_byte( check_vector_result ) ) -: 8];

always_ff @( posedge clk_i )
  if( check_error )
    orig_data_o <= check_data_ptrn;

always_ff @( posedge clk_i )
  if( readdatavalid_i )
    cur_check_addr <= check_addr_cnt;

generate
if( ADDR_TYPE == "BYTE" )
  begin

    localparam ADDR_CNT_W = ADDR_W - ADDR_B_W;

    logic [ADDR_CNT_W - 1 : 0] check_addr_cnt;

    always_ff @( posedge clk_i )
      if( load_stb )
        check_addr_cnt <= storage_struct.start_addr[ADDR_W - 1 : ADDR_B_W];
      else
        if( readdatavalid_i )
          check_addr_cnt <= check_addr_cnt + 1'b1;
  end
else
  if( ADDR_TYPE == "WORD" )
    begin

      logic [ADDR_W - 1 : 0] check_addr_cnt;

      always_ff @( posedge clk_i )
        if( load_stb )
          check_addr_cnt <= storage_struct.start_addr;
        else
          if( readdatavalid_i )
            check_addr_cnt <= check_addr_cnt + 1'b1;
    end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    stop_checker <= 1'b0;
  else
    if( start_test_i )
      stop_checker <= 1'b0;
    else
      if( check_error )
        stop_checker <= 1'b1;

always_ff @( posedge clk_i )
  if( !stop_checker )
    cmp_error_o <= ( check_error );

always_ff @( posedge clk_i )
  if( check_error )
    err_addr_o <= { cur_check_addr, err_byte( check_vector_result ) };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_busy_o <= 1'b0;
  else
    if( stop_checker )
      cmp_busy_o <= 1'b0;
    else
      if( cmp_en_i )
        cmp_busy_o <= 1'b1;
      else
        if( ( !in_process ) && storage_empty )
          cmp_busy_o <= 1'b0;
        else
          if( check_error )
            cmp_busy_o <= 1'b0;

assign check_error  = readdatavalid_delayed && ( &check_vector_result );
assign data_gen_bit = ( data_ptrn[6] ^ data_ptrn[1] ^ data_ptrn[0] );

endmodule : compare_block
