import rtl_settings_pkg::*;

module control_block(
  input                                                   rst_i,
  input                                                   clk_i,

  // CSR block interface
  input                                                   test_start_i,
  input         [CSR_SET_ADDR : CSR_TEST_PARAM][31 : 0]   test_param_i,
  
  output logic                                            test_finished_o,
  output logic                                            test_result_o,

  // Compare block interface
  input                                                   cmp_error_i,
  input                                                   cmp_busy_i,

  // Measure block interface
  input                                                   meas_busy_i,

  // Transmitter block interface
  input                                                   trans_ready_i,
  input                                                   trans_busy_i,

  output logic                                            trans_valid_o,
  output logic                                            trans_type_o,
  output logic  [ADDR_W - 1 : 0]                          trans_addr_o
);

logic                       next_addr_stb;
logic   [ADDR_W - 1 : 0]    next_addr;

address_block address_block_inst(
  .rst_i          ( rst_i         ),
  .clk_i          ( clk_i         ),

  .test_start_i   ( test_start_i  ),
  .test_param_i   ( test_param_i  ),

  .next_addr_en_i ( next_addr_stb ),

  .next_addr_o    ( next_addr     )
);

logic         [15 : 0]    test_count;
logic         [15 : 0]    cmd_cnt;

test_mode_t               test_mode;

logic                     last_transaction;
logic  [1 : 0]                   finish_flag;

logic                     last_transaction_stb;
logic                     cmd_accepted_stb;
logic                     addr_preset_stb;

logic                     trans_en_state; 
logic                     cnt_en_state;
logic                     finish_state;

enum logic [3:0] {
  IDLE_S,
  LOAD_S,
  WRITE_ONLY_S,
  READ_ONLY_S,
  WRITE_WORD_S,
  READ_WORD_S,
  END_TEST_S,
  SAVE_S,
  ERROR_CHECK_S
} state, next_state;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    state <= IDLE_S;
  else
    if( cmp_error_i )
      state <= ERROR_CHECK_S;
    else
      state <= next_state;

always_comb
  begin
    next_state = state;
    case( state )
      IDLE_S :
        begin
          if( test_start_i )
            next_state = LOAD_S;
        end

      LOAD_S :
        begin
          case( test_mode )
            READ_ONLY       : next_state = READ_ONLY_S;
            WRITE_ONLY      : next_state = WRITE_ONLY_S;
            WRITE_AND_CHECK : next_state = WRITE_WORD_S;
            default         : next_state = IDLE_S;
          endcase
        end

      READ_ONLY_S :
        begin
          if( last_transaction_stb )
            next_state = END_TEST_S;
        end

      WRITE_ONLY_S :
        begin
          if( last_transaction_stb )
            next_state = END_TEST_S;
        end

      WRITE_WORD_S :
        begin
          if( cmd_accepted_stb )
            next_state = READ_WORD_S;
        end

      READ_WORD_S :
        begin
          if( cmd_accepted_stb )
            if( last_transaction )
              next_state = END_TEST_S;
            else
              next_state = WRITE_WORD_S;
        end

      END_TEST_S :
        begin
          if( &finish_flag )
            next_state = SAVE_S;
        end

      ERROR_CHECK_S :
        begin
          if( &finish_flag )
            next_state = SAVE_S;
        end

      SAVE_S :
        begin
          if( &finish_flag )
            next_state = IDLE_S;
        end

      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    cmd_cnt <= test_count;
  else
    if( cmd_accepted_stb && cnt_en_state )
      cmd_cnt <= cmd_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    last_transaction <= ( test_count == 0 );
  else
    if( cmd_accepted_stb && cnt_en_state )
      last_transaction <= ( cmd_cnt == 1 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_valid_o <= 1'b0;
  else
    if( cmp_error_i )
      trans_valid_o <= 1'b0;
    else
      if( state == LOAD_S )
        trans_valid_o <= 1'b1;
      else
        if( cnt_en_state && last_transaction_stb )
          trans_valid_o <= 1'b0;

always_ff @( posedge clk_i )
  if( state == LOAD_S )
    trans_type_o <= ( test_mode == READ_ONLY );
  else
    case( state )
      WRITE_WORD_S :
        begin
          if( cmd_accepted_stb )
            trans_type_o <= 1'b1;
        end

      READ_WORD_S :
        begin
          if( cmd_accepted_stb )
            trans_type_o <= 1'b0;
        end
    endcase

always_ff @( posedge clk_i )
  if( next_addr_stb )
    trans_addr_o <= next_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    test_finished_o <= 1'b0;
  else
    if( test_start_i )
      test_finished_o <= 1'b0;
    else
      if( finish_state && ( &finish_flag ) )
        test_finished_o <= 1'b1;

always_ff @( posedge clk_i )
  if( test_start_i )
    test_result_o <= 1'b0;
  else
    if( cmp_error_i )
      test_result_o <= 1'b1;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    finish_flag <= 2'b00;
  else
    finish_flag <= { finish_flag[0], ( ( !cmp_busy_i ) && ( !meas_busy_i ) && ( !trans_busy_i ) ) };

assign trans_en_state       = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) ||
                              ( state == WRITE_WORD_S ) || ( state == READ_WORD_S );

assign cnt_en_state         = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) ||
                              ( state == READ_WORD_S  ); 

assign finish_state         = ( state == SAVE_S );//END_TEST_S   ) || ( state == ERROR_CHECK_S );

assign next_addr_stb        = ( state == LOAD_S       ) || ( cnt_en_state && cmd_accepted_stb );

// assign finish_flag          = ( !cmp_busy_i ) && ( !meas_busy_i ) && ( !trans_busy_i );

assign test_count           = test_param_i[CSR_TEST_PARAM][31 : 16];
assign test_mode            = test_mode_t'( test_param_i[CSR_TEST_PARAM][15 : 14] );

assign cmd_accepted_stb     = ( trans_valid_o   && trans_ready_i );
assign last_transaction_stb = ( last_transaction && cmd_accepted_stb );

endmodule : control_block
