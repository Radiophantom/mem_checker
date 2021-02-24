import rtl_settings_pkg::*;

module control_block(
  input                           rst_i,
  input                           clk_i,

  // CSR interface
  input                           start_test_i,
  input         [2 : 1][31 : 0]   test_param_i,
  
  output logic                    test_finished_o,
  output logic                    test_result_o,

  // Compare interface
  input                           cmp_error_i,
  input                           cmp_busy_i,

  // Measure interface
  input                           meas_busy_i,

  // Transmitter interface
  input                           trans_process_i,
  input                           trans_busy_i,

  output logic                    trans_valid_o,
  output logic                    trans_type_o,
  output logic  [ADDR_W - 1 : 0]  trans_addr_o
);

logic                       next_addr_stb;
logic   [ADDR_W - 1 : 0]    next_addr;

address_block address_block_inst(
  .rst_i          ( rst_i         ),
  .clk_i          ( clk_i         ),

  .start_test_i   ( start_test_i  ),
  .test_param_i   ( test_param_i  ),

  .next_addr_en_i ( next_addr_stb ),

  .next_addr_o    ( next_addr     )
);

logic         [15 : 0]    test_count;
logic         [15 : 0]    cmd_cnt;

test_mode_t               test_mode;

logic                     last_trans_flag;
logic                     finished_flag;

logic                     last_trans_stb;
logic                     cmd_accepted_stb;
logic                     preset_stb;

logic                     finished_state;
logic                     cnt_en_state;
logic                     trans_en_state; 

logic                     cmd_accept_ready;

enum logic [2:0] {
  IDLE_S,
  WRITE_ONLY_S,
  READ_ONLY_S,
  WRITE_WORD_S,
  READ_WORD_S,
  END_TEST_S,
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
          if( start_test_i )
            case( test_mode )
              READ_ONLY       : next_state = READ_ONLY_S;
              WRITE_ONLY      : next_state = WRITE_ONLY_S;
              WRITE_AND_CHECK : next_state = WRITE_WORD_S;
            endcase
        end

      READ_ONLY_S :
        begin
          if( last_trans_stb )
            next_state = END_TEST_S;
        end

      WRITE_ONLY_S :
        begin
          if( last_trans_stb )
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
            if( last_trans_flag )
              next_state = END_TEST_S;
            else
              next_state = WRITE_WORD_S;
        end

      END_TEST_S :
        begin
          if( finished_flag )
            next_state = IDLE_S;
        end

      ERROR_CHECK_S :
        begin
          if( finished_flag )
            next_state = IDLE_S;
        end

      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    preset_stb <= 1'b0;
  else
    preset_stb <= start_test_i;

always_ff @( posedge clk_i )
  if( start_test_i )
    cmd_cnt <= test_count;
  else
    if( cmd_accepted_stb && cnt_en_state )
      cmd_cnt <= cmd_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    last_trans_flag <= ( test_count == 0 );
  else
    if( cmd_accepted_stb && cnt_en_state )
      last_trans_flag <= ( cmd_cnt == 1 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_valid_o <= 1'b0;
  else
    if( cmp_error_i )
      trans_valid_o <= 1'b0;
    else
      if( trans_en_state )
        trans_valid_o <= ( !last_trans_stb );

always_ff @( posedge clk_i )
  if( trans_en_state )
    case( state )
      WRITE_ONLY_S : trans_type_o <= 1'b0;
      READ_ONLY_S  : trans_type_o <= 1'b1;
      WRITE_WORD_S : trans_type_o <= ( cmd_accepted_stb  );
      READ_WORD_S  : trans_type_o <= ( !cmd_accepted_stb );
      default      : trans_type_o <= 1'b0;
    endcase

always_ff @( posedge clk_i )
  if( next_addr_stb )
    trans_addr_o <= next_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    test_finished_o <= 1'b0;
  else
    test_finished_o <= ( finished_state && finished_flag );

always_ff @( posedge clk_i )
  if( start_test_i )
    test_result_o <= 1'b0;
  else
    if( cmp_error_i )
      test_result_o <= 1'b1;

assign trans_en_state     = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) ||
                            ( state == WRITE_WORD_S ) || ( state == READ_WORD_S );

assign cnt_en_state       = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S ) ||
                            ( state == READ_WORD_S  ); 

assign finished_state     = ( state == END_TEST_S   ) || ( state == ERROR_CHECK_S );

assign next_addr_stb      = ( preset_stb || ( cnt_en_state && cmd_accepted_stb ) );

assign finished_flag      = ( !cmp_busy_i ) && ( !meas_busy_i ) && ( !trans_busy_i );

assign test_count         = test_param_i[1][31 : 16];

assign test_mode          = test_mode_t'( test_param_i[1][15 : 14] );

assign cmd_accept_ready   = ( !trans_process_i );
assign cmd_accepted_stb   = ( trans_valid_o   && cmd_accept_ready );
assign last_trans_stb     = ( last_trans_flag && cmd_accepted_stb );

endmodule : control_block
