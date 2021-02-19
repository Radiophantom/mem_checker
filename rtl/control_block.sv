import rtl_settings_pkg::*;

module control_block(
  input                           rst_i,
  input                           clk_i,

  input                           start_test_i,

  input                           err_check_i,

  input                           cmp_block_busy_i,
  input                           meas_block_busy_i,
  input                           trans_block_busy_i,

  input         [2 : 1][31 : 0]   test_param_reg_i,
  
  output logic                    wr_result_o,
  output logic                    test_result_o,

  input                           in_process_i,

  output logic                    trans_valid_o,
  output logic  [ADDR_W - 1 : 0]  trans_addr_o,
  output logic                    trans_type_o
);

localparam int RND_ADDR_W = $bits( rnd_addr_reg );

// csr register casting
logic [15 : 0]                      test_count;
test_mode_t                         test_mode;
addr_mode_t                         addr_mode;
logic [AMM_BURST_W - 2 : 0]         burstcount_reg;
logic [ADDR_W - 1 : 0]              fix_addr_csr_reg;

// variables declaration
logic [15:0]                        cmd_cnt;
logic                               last_trans_flag, test_complete_flag;
logic                               test_complete_state;
logic                               cnt_en_state, trans_en_state; 

logic [ADDR_W - 1 : 0]              decoded_addr;
logic [ADDR_W - 1 : 0]              fix_addr_reg;
logic [ADDR_W - 1 : 0]              run_0_reg;
logic [ADDR_W - 1 : 0]              run_1_reg;
logic [ADDR_W - 1 : 0]              inc_addr_reg;
logic                               rnd_addr_gen_bit;

logic                               next_addr_stb;
logic                               next_addr_allowed;
logic                               cmd_accepted_stb;


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
    if( err_check_i )
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
          if( last_trans_flag && !in_process_i )
            next_state = END_TEST_S;
        end
      WRITE_ONLY_S :
        begin
          if( last_trans_flag && ( !in_process_i ) )
            next_state = END_TEST_S;
        end
      WRITE_WORD_S :
        begin
          if( !in_process_i )
            next_state = READ_WORD_S;
        end
      READ_WORD_S :
        begin
          if( last_trans_flag && ( !in_process_i ) )
            next_state = END_TEST_S;
          else if( !in_process_i )
            next_state = WRITE_WORD_S;
        end
      END_TEST_S :
        begin
          if( test_complete_flag )
            next_state = IDLE_S;
        end
      ERROR_CHECK_S :
        begin
          if( test_complete_flag )
            next_state = IDLE_S;
        end
      default :
        begin
          next_state = IDLE_S;
        end
    endcase
  end

generate
  if( ADDR_W <= 8 )
    begin
      logic [7:0] rnd_addr_reg;
      assign rnd_addr_gen_bit = rnd_addr_reg[7] ^ rnd_addr_reg[5] ^ rnd_addr_reg[4] ^ rnd_addr_reg[3];
    end
  else
    if( ADDR_W <= 16 )
      begin
        logic [15:0] rnd_addr_reg;
        assign rnd_addr_gen_bit = rnd_addr_reg[16] ^ rnd_addr_reg[7] ^ rnd_addr_reg[1];
      end
    else
      if( ADDR_W <= 32 )
        begin
          logic [31:0] rnd_addr_reg;
          assign rnd_addr_gen_bit = rnd_addr_reg[31] ^ rnd_addr_reg[21] ^ rnd_addr_reg[1] ^ rnd_addr_reg[0];
        end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr_reg <= { RND_ADDR_W{ 1'b1 } };
  else
    if( next_addr_stb && ( addr_mode == RND_ADDR ) )
      rnd_addr_reg <= { rnd_addr_reg[RND_ADDR_W - 2 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i )
  if( start_test_i && ( addr_mode == FIX_ADDR ) )
    fix_addr_reg <= fix_addr_csr_reg;

always_ff @( posedge clk_i )
  if( addr_mode == RUN_0_ADDR )
    if( start_test_i )
      run_0_reg <= { { (ADDR_W - 1){ 1'b1 }}, 1'b0 };
    else
      if( next_addr_stb )
        run_0_reg <= { run_0_reg[ADDR_W - 2 : 0], run_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode == RUN_1_ADDR )
    if( start_test_i )
      run_1_reg <= { { (ADDR_W - 1){ 1'b0 }}, 1'b1 };
    else
      if( next_addr_stb )
        run_1_reg <= { run_1_reg[ADDR_W - 2 : 0], run_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode == INC_ADDR )
    if( start_test_i )
      inc_addr_reg <= fix_addr_csr_reg;
    else
      if( next_addr_stb )
        inc_addr_reg <= inc_addr_reg + 1'b1;

always_comb
  case( addr_mode )
    FIX_ADDR    : decoded_addr = fix_addr_reg;
    RND_ADDR    : decoded_addr = rnd_addr_reg[ADDR_W - 1 : 0];
    RUN_0_ADDR  : decoded_addr = run_0_reg;
    RUN_1_ADDR  : decoded_addr = run_1_reg;
    INC_ADDR    : decoded_addr = inc_addr_reg;
    default     : decoded_addr = ADDR_W'( 0 );
  endcase

always_ff @( posedge clk_i )
  if( start_test_i )
    cmd_cnt <= test_count;
  else
    if( cmd_accepted_stb && cnt_en_state )
      cmd_cnt <= cmd_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    last_trans_flag <= ( test_count == 1 );
  else
    if( cmd_accepted_stb && cnt_en_state )
      last_trans_flag <= ( cmd_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_valid_o <= 1'b0;
  else
    if( err_check_i )
      trans_valid_o <= 1'b0;
    else
      if( trans_en_state )
        if( ( !trans_valid_o ) || ( !last_trans_flag ) )
          trans_valid_o <= 1'b1;
        else
          if( !in_process_i )
            trans_valid_o <= 1'b0;

always_ff @( posedge clk_i )
  if( trans_en_state )
    case( state )
      WRITE_ONLY_S : trans_type_o <= 1'b0;
      READ_ONLY_S  : trans_type_o <= 1'b1;
      WRITE_WORD_S : trans_type_o <= cmd_accepted_stb;
      READ_WORD_S  : trans_type_o <= ( !cmd_accepted_stb );
      default      : trans_type_o <= 1'b0;
    endcase

always_ff @( posedge clk_i )
  if( trans_en_state )
    if( !trans_valid_o || cmd_accepted_stb )
      trans_addr_o <= decoded_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_result_o <= 1'b0;
  else
    wr_result_o <= ( test_complete_state && test_complete_flag );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    test_result_o <= 1'b0;
  else
    if( start_test_i )
      test_result_o <= 1'b0;
    else
      if( err_check_i )
        test_result_o <= 1'b1;

assign trans_en_state       = ( state == WRITE_ONLY_S ) || ( state == READ_ONLY_S  ) ||
                              ( state == WRITE_WORD_S ) || ( state == READ_WORD_S  );

assign cnt_en_state         = ( state == READ_ONLY_S  ) || ( state == WRITE_ONLY_S ) ||
                              ( state == READ_WORD_S  );

assign next_addr_stb        = ( cnt_en_state && ( !trans_valid_o || cmd_accepted_stb ) );

assign test_complete_state  = ( state == END_TEST_S   ) || ( state == ERROR_CHECK_S );

assign cmd_accepted_stb     = ( trans_valid_o && ( !in_process_i ) );

assign test_complete_flag   = ( !cmp_block_busy_i && !meas_block_busy_i && !trans_block_busy_i );

assign test_count       = test_param_reg_i[1][31 : 16             ];
assign burstcount_reg   = test_param_reg_i[1][AMM_BURST_W - 2 : 0 ];
assign fix_addr_csr_reg = test_param_reg_i[2][ADDR_W - 1 : 0      ];

assign test_mode        = test_mode_t'( test_param_reg_i[1][15 : 14] );
assign addr_mode        = addr_mode_t'( test_param_reg_i[1][13 : 11] );

endmodule : control_block
