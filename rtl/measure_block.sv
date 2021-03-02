import rtl_settings_pkg::*;

module measure_block( 
  input                                               rst_i,
  input                                               clk_i,

  // Avalon-MM interface
  input                                               readdatavalid_i,
  input                                               waitrequest_i,

  input                                               read_i,
  input                                               write_i,
  input         [AMM_BURST_W - 1 : 0]                 burstcount_i,
  input         [DATA_B_W - 1 : 0]                    byteenable_i,

  // CSR block interface
  input                                               test_start_i,

  output logic                                        meas_busy_o,

  output logic  [CSR_RD_REQ : CSR_WR_TICKS][31 : 0]   meas_result_o
);

localparam CNT_NUM  = 4; // amount of cnt for concurrent read delay count
localparam CNT_W    = $clog2( CNT_NUM );

logic                 rd_req_flag;
logic                 rd_req_stb;
logic                 wr_unit_stb;
logic                 last_rd_word_stb;
logic [1 : 0]         save_delay_stb;
logic [1 : 0]         wr_stb_delayed;

logic [CNT_W - 1 : 0] load_cnt_num;
logic [CNT_W - 1 : 0] active_cnt_num;
logic [CNT_W - 1 : 0] save_cnt_num;

logic [31 : 0]        wr_ticks;
logic [31 : 0]        wr_units;
logic [31 : 0]        rd_ticks;
logic [31 : 0]        rd_words;
logic [31 : 0]        sum_delay;
logic [31 : 0]        rd_req_amount;

logic [15 : 0]        cmp_delay;
logic [15 : 0]        min_delay;
logic [15 : 0]        max_delay;

function automatic logic [ADDR_B_W : 0] bytes_count_func(
  logic [DATA_B_W/2 - 1 : 0] byteenable
);
  bytes_count_func = (ADDR_B_W + 1)'( 0 );
  for( int i = 0; i < DATA_B_W/2; i++ )
    if( byteenable[i] )
      bytes_count_func++;
endfunction : bytes_count_func

logic [CNT_NUM - 1 : 0][AMM_BURST_W - 1 : 0]  word_cnt_array;
logic [CNT_NUM - 1 : 0]                       delay_cnt_reg;
logic [CNT_NUM - 1 : 0][15 : 0]               delay_cnt_array;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_req_flag <= 1'b0;
  else
    if( read_i )
      rd_req_flag <= waitrequest_i;

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
    if( ( word_cnt_array[active_cnt_num] == 1 ) && readdatavalid_i )
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
      delay_cnt_reg[i] <= 1'b1;
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        delay_cnt_reg[i] <= 1'b0;

logic read_busy;

always_ff @( posedge clk_i )
  if( ( word_cnt_array[active_cnt_num] == 0 ) && ( delay_cnt_reg[active_cnt_num] == 1'b0 ) )
    read_busy <= 1'b0;
  else
    read_busy <= 1'b1;

always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      delay_cnt_array[i] <= 16'( 0 );
    else
      if( delay_cnt_reg[i] )
        delay_cnt_array[i] <= delay_cnt_array[i] + 1'b1;

always_ff @( posedge clk_i )
  if( test_start_i )
    rd_req_amount <= 32'( 0 );
  else
    if( read_i && ( !waitrequest_i ) )
      rd_req_amount <= rd_req_amount + 1'b1;

always_ff @( posedge clk_i )
  if( test_start_i )
    rd_words <= 32'( 0 );
  else
    if( readdatavalid_i )
      rd_words <= rd_words + 1'b1;

always_ff @( posedge clk_i )
  if( test_start_i )
    rd_ticks <= 32'( 0 );
  else
    if( read_busy )
      rd_ticks <= rd_ticks + 1'b1;

always_ff @( posedge clk_i )
  if( last_rd_word_stb )
    save_cnt_num <= active_cnt_num;

always_ff @( posedge clk_i )
  save_delay_stb <= { save_delay_stb[0], last_rd_word_stb };

always_ff @( posedge clk_i )
  cmp_delay <= delay_cnt_array[save_cnt_num];

always_ff @( posedge clk_i )
  if( test_start_i )
    min_delay <= 16'hFF_FF;
  else
    if( save_delay_stb[1] )
      if( cmp_delay < min_delay )
      min_delay <= cmp_delay;

always_ff @( posedge clk_i )
  if( test_start_i )
    max_delay <= 16'h0;
  else
    if( save_delay_stb[1] )
      if( cmp_delay > max_delay )
      max_delay <= cmp_delay;

always_ff @( posedge clk_i )
  if( test_start_i )
    sum_delay <= 32'( 0 );
  else
    if( save_delay_stb[1] )
      sum_delay <= sum_delay + cmp_delay;

assign meas_busy_o = ( !read_busy ) && ( !wr_stb_delayed );

always_ff @( posedge clk_i )
  if( test_start_i )
    wr_ticks <= 32'( 0 );
  else
    if( write_i )
      wr_ticks <= wr_ticks + 1'b1;

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address

      logic [2 : 0][(ADDR_B_W-1)/2+1 : 0] bytes_amount;

      always_ff @( posedge clk_i )
        if( wr_unit_stb )
          begin
            bytes_amount[0] <= bytes_count_func( byteenable_i[63 : 32] );
            bytes_amount[1] <= bytes_count_func( byteenable_i[31 : 0] );
          end

      always_ff @( posedge clk_i )
        if( wr_stb_delayed[0] )
          bytes_amount[2] <= bytes_amount[0] + bytes_amount[1];

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          wr_stb_delayed <= 1'b0;
        else
          wr_stb_delayed <= { wr_stb_delayed[0], wr_unit_stb };

      always_ff @( posedge clk_i )
        if( test_start_i )
          wr_units <= 32'( 0 );
        else
          if( wr_stb_delayed[1] )
            wr_units <= wr_units + bytes_amount[2];
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address

        always_ff @( posedge clk_i )
          if( test_start_i )
            wr_units <= 32'( 0 );
          else
            if( wr_unit_stb )
              wr_units <= wr_units + 1'b1;

      end
endgenerate 

logic last_rd_word;

assign rd_req_stb       = ( read_i  && ( !rd_req_flag   ) );
assign wr_unit_stb      = ( write_i && ( !waitrequest_i ) );

assign last_rd_word     = ( delay_cnt_array[active_cnt_num] == 1 );

assign last_rd_word_stb = ( last_rd_word && readdatavalid_i );

assign meas_result_o[CSR_WR_TICKS   ] = wr_ticks;
assign meas_result_o[CSR_WR_UNITS   ] = wr_units;
assign meas_result_o[CSR_RD_TICKS   ] = rd_ticks;
assign meas_result_o[CSR_RD_WORDS   ] = rd_words;
assign meas_result_o[CSR_MIN_MAX_DEL] = { min_delay, max_delay };
assign meas_result_o[CSR_SUM_DEL    ] = sum_delay;
assign meas_result_o[CSR_RD_REQ     ] = rd_req_amount;

endmodule : measure_block
