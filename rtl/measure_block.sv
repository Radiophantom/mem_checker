import settings_pkg::*;

module measure_block( 
  input                               rst_i,
  input                               clk_i,

  // Avalon-MM interface
  input                               rddatavalid_i,
  input                               waitrequest_i,

  input                               read_i,
  input                               write_i,
  input         [AMM_BURST_W - 1 : 0] burstcount_i,
  input         [DATA_B_W - 1 : 0]    byteenable_i,

  // CSR interface
  input                               start_test_i,

  output logic                        trans_block_busy_o,

  output logic  [31:0]                sum_delay_o,
  output logic  [15:0]                min_delay_o,
  output logic  [15:0]                max_delay_o,
  output logic  [31:0]                rd_req_cnt_o,
  output logic  [31:0]                rd_ticks_o,
  output logic  [31:0]                rd_words_count_o,

  output logic  [31:0]                wr_ticks_o,
  output logic  [31:0]                wr_units_count_o
);

localparam CNT_NUM  = 4;
localparam CNT_W    = $clog2( CNT_NUM );

function automatic logic [ADDR_B_W : 0] byte_amount_count(
  input logic [DATA_B_W - 1 : 0] byteenable_vec
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( byteenable_vec[i] )
      byte_amount_count++;
endfunction : byte_amount_count

logic unsigned [CNT_W - 1 : 0] act_cnt_num, load_cnt_num;
logic last_word_flag;
logic rd_mode_active;
logic wr_stb;
logic rd_stb;

logic [CNT_NUM - 1 : 0][AMM_BURST_W - 1 : 0] word_cnt_vec;
logic [CNT_NUM - 1 : 0] last_word_vec;
logic [CNT_NUM - 1 : 0][AMM_BURST_W - 1 : 0] act_delay_cnt_vec;
logic [CNT_W - 1 : 0] prev_cnt_num;
logic [ ] act_cnt_vec;
logic delay_cnt_vec;
logic wr_delay_stb;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    load_cnt_num <= CNT_W'( 0 );
  else
    if( rd_stb )
      load_cnt_num <= load_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_cnt_num <= CNT_W'( 0 );
  else
    if( last_word_flag )
      act_cnt_num <= act_cnt_num + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    word_cnt_vec = ( CNT_NUM * AMM_BURST_W )'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( ( i == load_cnt_num ) && rd_stb )
        word_cnt_vec[i] <= burstcount_i;
      else
        if( ( i == act_cnt_num ) && rddatavalid_i )
          word_cnt_vec[i] <= word_cnt_vec[i] - 1'b1; 

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_word_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( rd_stb && ( i == load_cnt_num ) )
        last_word_vec[i] <= ( burstcount_i == 1 );
      else
        if( rddatavalid_i && ( i == act_cnt_num ) )
          last_word_vec[i] <= ( word_cnt_vec[i] == 2 );

assign last_word_flag = last_word_vec[act_cnt_num] && rddatavalid_i;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_delay_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( rd_stb && ( i == load_cnt_num ) )
        act_delay_cnt_vec[i] <= 1'b1;
      else
        if( rddatavalid_i && ( i == act_cnt_num ) )
          act_delay_cnt_vec[i] <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    act_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( rd_stb && ( i == load_cnt_num ) )
        act_cnt_vec[i] <= 1'b1;
      else
        if( rddatavalid_i && ( i == act_cnt_num ) )
          act_cnt_vec[i] <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    delay_cnt_vec <= CNT_NUM'( 0 );
  else
    for( int i = 0; i < ( CNT_NUM - 1 ); i++ )
      if( act_delay_cnt_vec[i] )
        delay_cnt_vec[i] <= delay_cnt_vec[i] + 1'b1;
      else
        delay_cnt_vec[i] <= 32'( 0 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    prev_cnt_num <= CNT_W'( 0 );
  else
    if( last_word_flag )
      prev_cnt_num <= act_cnt_num;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_delay_stb <= 1'b0;
  else
    wr_delay_stb <= last_word_flag;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_req_cnt_o <= 32'( 0 );
  else
    if( start_test_i )
      rd_req_cnt_o <= 32'( 0 );
    else
      if( wr_delay_stb )
        rd_req_cnt_o <= rd_req_cnt_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_words_count_o <= 32'( 0 );
  else
    if( start_test_i )
      rd_words_count_o <= 32'( 0 );
    else
      if( rddatavalid_i )
        rd_words_count_o <= rd_words_count_o + 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    min_delay_o <= 16'hFF_FF;
  else
    if( start_test_i )
      min_delay_o <= 16'hFF_FF;
    else
      if( wr_delay_stb && ( delay_cnt_vec[prev_cnt_num] < min_delay_o ) )
        min_delay_o <= delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    max_delay_o <= 16'h0;
  else
    if( start_test_i )
      max_delay_o <= 16'h0;
    else
      if( wr_delay_stb && ( delay_cnt_vec[prev_cnt_num] > max_delay_o ) )
        max_delay_o <= delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    sum_delay_o <= 32'( 0 );
  else
    if( start_test_i )
      sum_delay_o <= 32'( 0 );
    else
      if( wr_delay_stb )
        sum_delay_o <= sum_delay_o + delay_cnt_vec[prev_cnt_num];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_ticks_o <= 32'( 0 );
  else
    if( start_test_i )
      rd_ticks_o <= 32'( 0 );
    else
      if( rd_mode_active )
        rd_ticks_o <= rd_ticks_o + 1'b1;

assign rd_mode_active = ( |act_delay_cnt_vec );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_ticks_o <= 32'( 0 );
  else
    if( start_test_i )
      wr_ticks_o <= 32'( 0 );
    else
      if( write_i )
        wr_ticks_o <= wr_ticks_o + 1'b1;

assign wr_stb = ( write_i && !waitrequest_i );

generate
  if( ADDR_TYPE == BYTE )
    begin : byte_address

      logic [BYTE_ADDR_W : 0] byte_amount;
      logic                   delayed_wr_stb;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          byte_amount <= ( BYTE_ADDR_W + 1 )'( 0 );
        else
          if( start_test_i )
            byte_amount <= ( BYTE_ADDR_W + 1 )'( 0 );
          else
            if( wr_stb )
              byte_amount <= byte_amount_func( byteenable_i );

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          delayed_wr_stb <= 1'b0;
        else
          delayed_wr_stb <= wr_stb;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          wr_units_count_o <= 32'( 0 );
        else
          if( start_test_i )
            wr_units_count_o <= 32'( 0 );
          else
            if( delayed_wr_stb )
              wr_units_count_o <= wr_units_count_o + byte_amount;
    end
  else
    if( ADDR_TYPE == WORD )
      begin : word_address

        always_ff @( posedge clk_i, posedge rst_i )
          if( rst_i )
            wr_units_count_o <= 32'( 0 );
          else
            if( start_test_i )
              wr_units_count_o <= 32'( 0 );
            else
              if( wr_stb )
                wr_units_count_o <= wr_units_count_o + 1'b1;
      end
endgenerate 

assign rd_stb = ( read_i && !waitrequest_i ); 

endmodule
