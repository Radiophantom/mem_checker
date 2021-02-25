import rtl_settings_pkg::*;

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
  output logic  [31 : 0]              err_data_o,

  output logic                        cmp_busy_o
);

localparam int CMP_W      = $bits( cmp_struct_t             );
localparam int ADDR_CNT_W = $bits( cmp_struct_t.start_addr  );

fifo #(
  .AWIDTH   ( 2               ),
  .DWIDTH   ( CMP_W           )
) cmp_fifo_inst (
  .clk_i    ( clk_i           ),
  .srst_i   ( start_test_i    ),

  .wrreq_i  ( cmp_en_i        ),
  .data_i   ( cmp_struct_i    ),

  .rdreq_i  ( rd_cmp_fifo     ),
  .q_o      ( cmp_fifo_q      ),

  .empty_o  ( cmp_fifo_empty  )
);

fifo #(
  .AWIDTH   ( 3               ),
  .DWIDTH   ( AMM_DATA_W      )
) data_fifo_inst (
  .clk_i    ( clk_i           ),
  .srst_i   ( start_test_i    ),

  .wrreq_i  ( readdatavalid_i ),
  .data_i   ( readdata_i      ),

  .rdreq_i  ( rd_data_fifo    ),
  .q_o      ( data_fifo_q     ),

  .empty_o  ( data_fifo_empty )
);

cmp_struct_t                        storage_struct;

logic   [CMP_W - 1      : 0]        cmp_fifo_q;
logic   [AMM_DATA_W - 1 : 0]        data_fifo_q;

logic   [ADDR_CNT_W - 1 : 0]        check_addr_cnt;
logic   [ADDR_CNT_W - 1 : 0]        check_addr;

logic   [ADDR_B_W - 1 : 0]          err_byte_num;
logic   [7 : 0]                     err_byte;

logic   [DATA_B_W - 1 : 0]          check_ptrn;
logic   [DATA_B_W - 1 : 0]          check_vector_result;
logic   [7 : 0]                     data_ptrn;

logic   [AMM_BURST_W - 2 : 0]       word_cnt;
logic                               last_word;

logic   [1 : 0]                     pipe_stage_en;
logic   [1 : 0][7 : 0]              check_data_ptrn;
logic   [1 : 0][AMM_DATA_W - 1 : 0] check_readdata;

logic                               rd_data_fifo, data_fifo_empty;
logic                               rd_cmp_fifo,  cmp_fifo_empty;

logic                               check_error;
logic                               lock_error_stb;

logic                               data_gen_bit;

mask_t                              mask_struct;

state_t                             state, next_state;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    if( check_error )
      state <= ERROR_S;
    else
      state <= next_state;

always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S :
        begin
          if( !cmp_fifo_empty )
            next_state = CALC_MASK_S;
        end

      CALC_MASK_S :
        begin
          next_state = LOAD_S;
        end

      LOAD_S :
        begin
          next_state = CHECK_S;
        end

      CHECK_S :
        begin
          if( last_word && rd_data_fifo )
            next_state = IDLE_S;
        end

      ERROR_S :
        begin
          if( start_test_i )
            next_state = IDLE_S;
        end

      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i )
  if( state == CALC_MASK_S )
    begin
      mask_struct.first   <= byteenable_ptrn( 1'b1, storage_struct.start_off, 1'b0, storage_struct.end_off );
      mask_struct.last    <= byteenable_ptrn( 1'b0, storage_struct.start_off, 1'b1, storage_struct.end_off );
      mask_struct.merged  <= byteenable_ptrn( 1'b1, storage_struct.start_off, 1'b1, storage_struct.end_off );
    end

always_ff @( posedge clk_i )
  if( state == CALC_MASK_S )
    word_cnt <= storage_struct.words_count;
  else
    if( rd_data_fifo )
      word_cnt <= word_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( state == CALC_MASK_S )
    last_word <= ( storage_struct.words_count == 0 );
  else
    if( rd_data_fifo )
      last_word <= ( word_cnt == 1 );

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    if( last_word )
      check_ptrn <= mask_struct.merged;
    else
      check_ptrn <= mask_struct.first;
  else
    if( pipe_stage_en[0] )
      if( last_word )
        check_ptrn <= mask_struct.last;
      else
        check_ptrn <= '1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    pipe_stage_en <= 2'b00;
  else
    pipe_stage_en <= { pipe_stage_en[0], rd_data_fifo };

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    data_ptrn <= storage_struct.data_ptrn;
  else
    if( storage_struct.data_mode == RND_DATA )
      if( pipe_stage_en[0] )
        data_ptrn <= { data_ptrn[6:0], data_gen_bit };

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    check_addr_cnt <= storage_struct.start_addr;
  else
    if( pipe_stage_en[1] )
      check_addr_cnt <= check_addr_cnt + 1'b1;

always_ff @( posedge clk_i )
  if( pipe_stage_en[1] )
    check_addr <= check_addr_cnt;

always_ff @( posedge clk_i )
  if( pipe_stage_en[0] )
    check_vector_result <= check_vector( check_ptrn, data_ptrn, data_fifo_q );

always_ff @( posedge clk_i )
  if( |pipe_stage_en )
    check_data_ptrn <= { check_data_ptrn[0], data_ptrn };

always_ff @( posedge clk_i )
  if( |pipe_stage_en )
    check_readdata <= { check_readdata[0], data_fifo_q };

always_ff @( posedge clk_i )
  if( pipe_stage_en[1] )
    err_byte_num = err_byte_find( check_vector_result );

always_ff @( posedge clk_i )
  if( pipe_stage_en[1] )
    check_error <= ( &check_vector_result );
  else
    check_error <= 1'b0;

always_ff @( posedge clk_i )
  if( lock_error_stb )
    err_addr_o <= { check_addr, err_byte_num };

always_ff @( posedge clk_i )
  if( lock_error_stb )
    err_data_o <= { err_byte, check_data_ptrn[1] };

always_ff @( posedge clk_i )
  if( start_test_i )
    cmp_error_o <= 1'b0;
  else
    if( check_error )
      cmp_error_o <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_busy_o <= 1'b0;
  else
    if( check_error )
      cmp_busy_o <= 1'b0;
    else
      if( state == IDLE_S )
        cmp_busy_o <= ( !cmp_fifo_empty );

/*
generate
  if( ADDR_TYPE == "BYTE" )
    begin

    end
  else
    if( ADDR_TYPE == "WORD" )
      begin

      end
endgenerate
*/

assign rd_cmp_fifo      = ( state == IDLE_S   ) && ( !cmp_fifo_empty  );
assign rd_data_fifo     = ( state == CHECK_S  ) && ( !data_fifo_empty );

assign err_byte         = check_readdata[1][7 + 8 * ( err_byte_num ) -: 8];
assign data_gen_bit     = ( data_ptrn[6] ^ data_ptrn[1] ^ data_ptrn[0] );

assign storage_struct   = cmp_struct_t'( cmp_fifo_q );

assign lock_error_stb   = check_error && ( !cmp_error_o );

endmodule : compare_block
