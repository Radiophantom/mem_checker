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
  input         [DATA_B_W - 1    : 0]                 byteenable_i,

  // CSR block interface
  input                                               test_start_i,

  output logic                                        meas_busy_o,

  output logic  [CSR_RD_REQ : CSR_WR_TICKS][31 : 0]   meas_result_o
);

// pipeline width must be power of 2
localparam int PIPE_W   = 16;
// amount of cnt for concurrent read delay counting
localparam int CNT_NUM  = 4;
localparam int CNT_W    = $clog2( CNT_NUM );

//********
// Variables declaration
//********

logic                 rd_req_flag;
logic                 rd_req_stb;
logic                 wr_unit_stb;
logic                 rd_ticks_count_en;

logic [1 : 0]         save_stb_delayed;

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

logic                 write_busy;
logic                 read_busy;

logic                 last_word;
logic                 last_word_stb;

logic [CNT_NUM - 1 : 0][AMM_BURST_W - 1 : 0]  word_cnt_array;
logic [CNT_NUM - 1 : 0]                       delay_cnt_reg;
logic [CNT_NUM - 1 : 0][15 : 0]               delay_cnt_array;

//*******
// Read transactions tick count
//*******

// read signal state save for first strobe detect
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_req_flag <= 1'b0;
  else
    if( read_i )
      if( waitrequest_i )
        rd_req_flag <= 1'b1;
      else
        rd_req_flag <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_busy <= 1'b0;
  else
    if( rd_req_stb )
      read_busy <= 1'b1;
    else
      read_busy <= ( active_cnt_num != load_cnt_num );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rd_ticks_count_en <= 1'b0;
  else
    rd_ticks_count_en <= ( active_cnt_num != load_cnt_num );

  always_ff @( posedge clk_i )
  if( test_start_i )
    rd_ticks <= 32'( 0 );
  else
    if( rd_ticks_count_en )
      rd_ticks <= rd_ticks + 1'b1;

//********
// Read delay count logic
//*******

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
    if( last_word_stb )
      active_cnt_num <= active_cnt_num + 1'b1;

// latch read request burstcount and count to 0 and stop
always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      word_cnt_array[i] <= burstcount_i;
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        word_cnt_array[i] <= word_cnt_array[i] - 1'b1;

// delay count enable flags
always_ff @( posedge clk_i )
  for( int i = 0; i < CNT_NUM; i++ )
    if( rd_req_stb && ( load_cnt_num == i ) )
      delay_cnt_reg[i] <= 1'b1;
    else
      if( readdatavalid_i && ( active_cnt_num == i ) )
        delay_cnt_reg[i] <= 1'b0;

// delay counters
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

// save current cnt number to save delay
always_ff @( posedge clk_i )
  if( last_word_stb )
    save_cnt_num <= active_cnt_num;

// save strobe pipe
always_ff @( posedge clk_i )
  save_stb_delayed <= { save_stb_delayed[0], last_word_stb };

// save current counter value
always_ff @( posedge clk_i )
  cmp_delay <= delay_cnt_array[save_cnt_num];

always_ff @( posedge clk_i )
  if( test_start_i || save_stb_delayed[1] )
    if( test_start_i )
      min_delay <= 16'hFF_FF;
    else
      if( cmp_delay < min_delay )
        min_delay <= cmp_delay;

always_ff @( posedge clk_i )
  if( test_start_i || save_stb_delayed[1] )
    if( test_start_i )
      max_delay <= 16'h0;
    else
      if( cmp_delay > max_delay )
        max_delay <= cmp_delay;

always_ff @( posedge clk_i )
  if( test_start_i )
    sum_delay <= 32'( 0 );
  else
    if( save_stb_delayed[1] )
      sum_delay <= sum_delay + cmp_delay;

//******************
// Write units statistics
//***********

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address
      //----------------------------------------------------------------------------------
      localparam int INPUTS_AMOUNT  = ( DATA_B_W > PIPE_W ) ? ( DATA_B_W / PIPE_W ) : ( 1 );

      if( INPUTS_AMOUNT > 1 )
        begin
          //----------------------------------------------------------------------------------
          localparam int STAGE_W        = $clog2( PIPE_W ) + 1;
          localparam int STAGES_AMOUNT  = $clog2( INPUTS_AMOUNT );
          localparam int SUM_W          = STAGES_AMOUNT + STAGE_W;

          logic [STAGES_AMOUNT - 1 : 0][INPUTS_AMOUNT - 1 : 0][SUM_W - 1   : 0] bytes_amount_sum;
          logic                        [INPUTS_AMOUNT - 1 : 0][STAGE_W - 1 : 0] bytes_amount;

          logic [STAGES_AMOUNT : 0] wr_stb_delayed;

          // split byteenable and count bytes in each nibble
          always_ff @( posedge clk_i )
            if( wr_unit_stb )
              for( int i = 0; i < INPUTS_AMOUNT; i++ ) 
                bytes_amount[i] <= STAGE_W'( bytes_count( byteenable_i[( PIPE_W - 1 ) + i * PIPE_W -: PIPE_W] ) );

          // pipeline adder
          always_ff @( posedge clk_i )
            begin
              for( int j = 0; j < INPUTS_AMOUNT / 2; j++ )
                bytes_amount_sum[0][j] <= bytes_amount[j * 2] + bytes_amount[j * 2 + 1];
              for( int i = 1; i < STAGES_AMOUNT; i++ )
                for( int j = 0; j < INPUTS_AMOUNT / (i * 2); j++ )
                  bytes_amount_sum[i][j] <= bytes_amount_sum[i - 1][j * 2] + bytes_amount_sum[i - 1][j * 2 + 1];
            end

          always_ff @( posedge clk_i, posedge rst_i )
            if( rst_i )
              wr_stb_delayed <= STAGES_AMOUNT'( 0 );
            else
              wr_stb_delayed <= { wr_stb_delayed[STAGES_AMOUNT - 1 : 0], wr_unit_stb };

          always_ff @( posedge clk_i )
            if( test_start_i )
              wr_units <= 32'( 0 );
            else
              if( wr_stb_delayed[STAGES_AMOUNT] )
                wr_units <= wr_units + bytes_amount_sum[STAGES_AMOUNT - 1][0];

          // if any of pipe stages is active - block is busy
          assign write_busy = ( |wr_stb_delayed );
          //----------------------------------------------------------------------------------
        end
      else
        begin
          //----------------------------------------------------------------------------------
          localparam int SUM_W = $clog2( DATA_B_W ) + 1;

          logic [SUM_W - 1 : 0] bytes_amount;
          logic                 wr_stb_delayed;

          always_ff @( posedge clk_i )
            if( wr_unit_stb )
              bytes_amount <= SUM_W'( bytes_count( byteenable_i ) );

          always_ff @( posedge clk_i, posedge rst_i )
            if( rst_i )
              wr_stb_delayed <= 1'b0;
            else
              wr_stb_delayed <= wr_unit_stb;

          always_ff @( posedge clk_i )
            if( test_start_i )
              wr_units <= 32'( 0 );
            else
              if( wr_stb_delayed )
                wr_units <= wr_units + bytes_amount;

          assign write_busy = wr_stb_delayed;
          //----------------------------------------------------------------------------------
        end
      //----------------------------------------------------------------------------------
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address
        //----------------------------------------------------------------------------------
        always_ff @( posedge clk_i )
          if( test_start_i )
            wr_units <= 32'( 0 );
          else
            if( wr_unit_stb )
              wr_units <= wr_units + 1'b1;

        assign write_busy = 1'b0;
        //----------------------------------------------------------------------------------
      end
endgenerate 

always_ff @( posedge clk_i )
  if( test_start_i )
    wr_ticks <= 32'( 0 );
  else
    if( write_i )
      wr_ticks <= wr_ticks + 1'b1;

assign rd_req_stb     = ( read_i  && ( !rd_req_flag   ) );
assign wr_unit_stb    = ( write_i && ( !waitrequest_i ) );

assign last_word      = ( word_cnt_array[active_cnt_num] == 1 );
assign last_word_stb  = ( last_word && readdatavalid_i  );

assign meas_busy_o    = ( read_busy || write_busy );

assign meas_result_o[CSR_WR_TICKS ] = wr_ticks;
assign meas_result_o[CSR_WR_UNITS ] = wr_units;
assign meas_result_o[CSR_RD_TICKS ] = rd_ticks;
assign meas_result_o[CSR_RD_WORDS ] = rd_words;
assign meas_result_o[CSR_MIN_DEL  ] = min_delay;
assign meas_result_o[CSR_MAX_DEL  ] = max_delay;
assign meas_result_o[CSR_SUM_DEL  ] = sum_delay;
assign meas_result_o[CSR_RD_REQ   ] = rd_req_amount;

endmodule : measure_block
