import rtl_settings_pkg::*;

module measure_block( 
  input                               rst_i,
  input                               clk_i,

  // Avalon-MM interface
  input                               readdatavalid_i,
  input                               waitrequest_i,

  input                               read_i,
  input                               write_i,
  input         [AMM_BURST_W - 1 : 0] burstcount_i,
  input         [DATA_B_W - 1 : 0]    byteenable_i,

  // CSR interface
  input                               start_test_i,

  output logic                        meas_block_busy_o,

  output logic  [31:0]                wr_ticks_o,
  output logic  [31:0]                wr_units_o,
  output logic  [31:0]                rd_ticks_o,
  output logic  [31:0]                rd_words_o,
  output logic  [31:0]                min_max_delay_o,
  output logic  [31:0]                sum_delay_o,
  output logic  [31:0]                rd_req_amount_o
);

localparam CNT_NUM  = 4; // amount of cnt for concurrent delay count
localparam CNT_W    = $clog2( CNT_NUM );

function automatic logic [ADDR_B_W : 0] bytes_count_func(
  logic [DATA_B_W - 1 : 0] byteenable
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( byteenable[i] )
      bytes_count_func++;
endfunction : bytes_count_func

logic                 rd_req_flag;
logic                 rd_req_stb;
logic                 wr_unit_stb;
logic                 last_rd_word_stb;
logic                 save_delay_stb;

logic [CNT_W - 1 : 0] load_cnt_num;
logic [CNT_W - 1 : 0] active_cnt_num;
logic [CNT_W - 1 : 0] save_cnt_num;

logic [15 : 0]        min_delay;
logic [15 : 0]        max_delay;

/*
always_ff @( posedge clk_i )
  if( start_test_i )
    wr_units_o <= 32'( 0 );
  else
    if( wr_start_stb )
      wr_units_o <=  wr_units_o + burstcount_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_start_flag <= 1'b0;
  else
    if( in_process )
      wr_start_flag <= ( last_word && ( !waitrequest_i ) );
    else
      wr_start_flag <= 1'b1;

always_ff @( posedge clk_i )
  if( wr_start_flag && write_i && !waitrequest_i )
    wr_cnt <= burstcount_i;
  else
    if( !wr_start_flag && write_i && !waitrequest_i )
      wr_cnt <= wr_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( !wr_start_flag && write_i && !waitrequest_i )
    last_word <= ( wr_cnt == 2 );
*/

logic [CNT_NUM - 1 : 0][AMM_BURST_W - 1 : 0]  word_cnt_array;
logic [CNT_NUM - 1 : 0]                       last_rd_word_reg;
logic [CNT_NUM - 1 : 0]                       delay_cnt_reg;
logic [CNT_NUM - 1 : 0]                       trans_cnt_reg;
logic [CNT_NUM - 1 : 0][15 : 0]               delay_cnt_array;
logic [CNT_NUM - 1 : 0][31 : 0]               trans_cnt_array;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_req_flag <= 1'b0;
  else
    if( read_i )
      if( !waitrequest_i )
        rd_req_flag <= 1'b0;
      else
        rd_req_flag <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_cnt_num <= CNT_W'( 0 );
  else
    if( rd_req_stb )
      load_cnt_num <= load_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    active_cnt_num <= CNT_W'( 0 );
  else
    if( last_rd_word_stb )
      active_cnt_num <= active_cnt_num + 1'b1;

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      word_cnt_array[i] <= burstcount_i;
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        word_cnt_array[i] <= word_cnt_array[i] - 1'b1; 

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      last_rd_word_reg[i] <= ( burstcount_i == 1 );
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        last_rd_word_reg[i] <= ( word_cnt_array[i] == 2 );

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      delay_cnt_reg[i] <= 1'b1;
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        delay_cnt_reg[i] <= 1'b0;

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      trans_cnt_reg[i] <= 1'b1;
    else
      if( last_rd_word_reg[i] && readdatavalid_i && ( active_cnt_num == i ) )
        trans_cnt_reg[i] <= 1'b0;

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      delay_cnt_array[i] <= 16'( 0 );
    else
      if( delay_cnt_reg[i] )
        delay_cnt_array[i] <= delay_cnt_array[i] + 1'b1;

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      trans_cnt_array[i] <= 32'( 0 );
    else
      if( trans_cnt_reg[i] )
        trans_cnt_array[i] <= trans_cnt_array[i] + 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    rd_req_amount_o <= 32'( 0 );
  else
    if( save_delay_stb )
      rd_req_amount_o <= rd_req_amount_o + 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    rd_words_o <= 32'( 0 );
  else
    if( readdatavalid_i )
      rd_words_o <= rd_words_o + 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    rd_ticks_o <= 32'( 0 );
  else
    if( |trans_cnt_reg )
      rd_ticks_o <= rd_ticks_o + 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    wr_ticks_o <= 32'( 0 );
  else
    if( write_i )
      wr_ticks_o <= wr_ticks_o + 1'b1;

always_ff @( posedge clk_i )
  if( last_rd_word_stb )
    save_cnt_num <= active_cnt_num;

always_ff @( posedge clk_i )
  save_delay_stb <= last_rd_word_stb;

/*always_ff @( posedge clk_i )
  if( start_test_i )
    min_delay <= 16'hFF_FF;
  else
    if( save_delay_stb && ( delay_cnt_array[save_cnt_num] < min_delay ) )
      min_delay <= delay_cnt_array[save_cnt_num];

always_ff @( posedge clk_i )
  if( start_test_i )
    max_delay <= 16'h0;
  else
    if( save_delay_stb && ( delay_cnt_array[save_cnt_num] > max_delay ) )
      max_delay <= delay_cnt_array[save_cnt_num];
*/
always_ff @( posedge clk_i )
  if( start_test_i )
    sum_delay_o <= 32'( 0 );
  else
    if( save_delay_stb )
      sum_delay_o <= sum_delay_o + delay_cnt_array[save_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    meas_block_busy_o <= 1'b0;
  else
    meas_block_busy_o <= ( |trans_cnt_reg );

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address

/*      logic [ADDR_B_W : 0] bytes_amount;
      logic                wr_dly_stb;

      always_ff @( posedge clk_i )
        if( wr_unit_stb )
          bytes_amount <= bytes_count_func( byteenable_i );

      always_ff @( posedge clk_i )
        wr_dly_stb <= wr_unit_stb;

      always_ff @( posedge clk_i )
        if( start_test_i )
          wr_units_o <= 32'( 0 );
        else
          if( wr_dly_stb )
            wr_units_o <= wr_units_o + bytes_amount;
*/
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address

        always_ff @( posedge clk_i )
          if( start_test_i )
            wr_units_o <= 32'( 0 );
          else
            if( wr_unit_stb )
              wr_units_o <= wr_units_o + 1'b1;

      end
endgenerate 

assign rd_req_stb       = ( read_i  && ( !rd_req_flag   ) );
assign wr_unit_stb      = ( write_i && ( !waitrequest_i ) );

assign last_rd_word_stb = last_rd_word_reg[active_cnt_num] && readdatavalid_i;

assign min_max_delay_o  = { min_delay, max_delay };

endmodule : measure_block
