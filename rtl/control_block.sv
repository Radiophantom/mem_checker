import settings_pkg::*;

module control_block(
  input                         rst_i,
  input                         clk_i,

  input                         start_test_i,

  input                         err_check_i,

  input                         cmp_block_busy_i,
  input                         meas_block_busy_i,
  input                         trans_block_busy_i,

  input         [2 : 1][31 : 0] test_param_reg_i,
  
  input                         cmd_accept_ready_i,

  output logic                  wr_result_o,

  output logic                  op_valid_o,
  output trans_struct_t         op_pkt_o
);

localparam int RND_ADDR_W = $bits( rnd_addr_reg );

// csr register casting
logic [15 : 0]                      test_count_reg;
test_mode_t                         test_mode_reg;
addr_mode_t                         addr_mode_reg;
logic [AMM_BURST_W - 2 : 0]         burstcount_csr_reg;
logic [ADDR_W - 1 : 0]              fix_addr_csr_reg;

assign test_count_reg     = test_param_reg_i[1][31 : 16];
assign test_mode_reg      = test_param_reg_i[1][15 : 14];
assign addr_mode_reg      = test_param_reg_i[1][13 : 11];
assign burstcount_csr_reg = test_param_reg_i[1][AMM_BURST_W - 2 : 0];
assign fix_addr_csr_reg   = test_param_reg_i[2][ADDR_W - 1 : 0];

// variables declaration
logic [15:0]                        cmd_cnt;
logic                               last_trans_flg, test_complete_flg;
logic                               test_complete_state;
logic                               cnt_en_state, trans_en_state; 

logic                               rnd_addr_gen_bit;
logic [ADDR_W - 1 : 0]              fix_addr_reg;
logic [ADDR_W - 1 : 0]              run_0_reg;
logic [ADDR_W - 1 : 0]              run_1_reg;
logic [ADDR_W - 1 : 0]              inc_addr_reg;

logic                               next_addr_stb;
logic                               next_addr_allowed;
logic                               cmd_accepted_stb;
logic [ADDR_B_W - 1 : 0]            start_offset;
logic [ADDR_B_W - 1 : 0]            end_offset;

logic [ADDR_B_W - 1 : 0]            low_burst_bits;
logic [ADDR_W - 1 : 0]              decoded_addr;

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
            case( test_mode_reg )
              READ_ONLY       : next_state = READ_ONLY_S;
              WRITE_ONLY      : next_state = WRITE_ONLY_S;
              WRITE_AND_CHECK : next_state = WRITE_WORD_S;
            endcase
        end
      READ_ONLY_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
        end
      WRITE_ONLY_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
        end
      WRITE_WORD_S :
        begin
          if( cmd_accept_ready_i )
            next_state = READ_WORD_S;
        end
      READ_WORD_S :
        begin
          if( last_trans_flg && cmd_accept_ready_i )
            next_state = END_TEST_S;
          else if( cmd_accept_ready_i )
            next_state = WRITE_WORD_S;
        end
      END_TEST_S :
        begin
          if( test_complete_flg )
            next_state = IDLE_S;
        end
      ERROR_CHECK_S :
        begin
          if( test_complete_flg )
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
    if( next_addr_stb && addr_mode_reg == RND_ADDR )
      rnd_addr_reg <= { rnd_addr_reg[RND_ADDR_W - 2 : 0], rnd_addr_gen_bit };

always_ff @( posedge clk_i )
  if( start_test_i && addr_mode_reg == FIX_ADDR )
    fix_addr_reg <= fix_addr_csr_reg;

always_ff @( posedge clk_i )
  if( addr_mode_reg == RUN_0_ADDR )
    if( start_test_i )
      run_0_reg <= { ADDR_W{ 1'b1 } } - 1'b1;
    else
      if( next_addr_stb )
        run_0_reg <= { run_0_reg[ADDR_W - 2 : 0], run_0_reg[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode_reg == RUN_1_ADDR )
    if( start_test_i )
      run_1_reg <= { ADDR_W{ 1'b0 } } + 1'b1;
    else
      if( next_addr_stb )
        run_1_reg <= { run_1_reg[ADDR_W - 2 : 0], run_1_reg[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode_reg == INC_ADDR )
    if( start_test_i )
      inc_addr_reg <= fix_addr_csr_reg;
    else
      if( next_addr_stb )
        inc_addr_reg <= inc_addr_reg + 1'b1;

always_comb
  case( test_mode_reg )
    FIX_ADDR    : decoded_addr = fix_addr_reg;
    RND_ADDR    : decoded_addr = rnd_addr_reg[ADDR_W - 1 : 0];
    RUN_0_ADDR  : decoded_addr = run_0_reg;
    RUN_1_ADDR  : decoded_addr = run_1_reg;
    INC_ADDR    : decoded_addr = inc_addr_reg;
    default     : decoded_addr = ADDR_W'( 0 );
  endcase

always_ff @( posedge clk_i )
  if( start_test_i )
    cmd_cnt <= test_count_reg;
  else
    if( cmd_accepted_stb && cnt_en_state )
      cmd_cnt <= cmd_cnt - 1'b1;

always_ff @( posedge clk_i )
  if( start_test_i )
    last_trans_flg <= ( test_count_reg == 1 );
  else
    if( cmd_accepted_stb && cnt_en_state )
      last_trans_flg <= ( cmd_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    op_valid_o <= 1'b0;
  else
    if( err_check_i )
      op_valid_o <= 1'b0;
    else
      if( trans_en_state )
        if( !op_valid_o || !last_trans_flg )
          op_valid_o <= 1'b1;
        else
          if( cmd_accept_ready_i )
            op_valid_o <= 1'b0;

always_ff @( posedge clk_i )
  if( trans_en_state )
    case( state )
      WRITE_ONLY_S : op_pkt_o.pkt_type <= 1'b0;
      READ_ONLY_S  : op_pkt_o.pkt_type <= 1'b1;
      WRITE_WORD_S : op_pkt_o.pkt_type <= cmd_accepted_stb;
      READ_WORD_S  : op_pkt_o.pkt_type <= !cmd_accepted_stb;
      default      : op_pkt_o.pkt_type <= 1'b0;
    endcase

always_ff @( posedge clk_i )
  if( trans_en_state )
    if( !op_valid_o || cmd_accepted_stb )
    begin
      if( ADDR_TYPE == "BYTE" )
        begin
          op_pkt_o.word_addr      <= { decoded_addr[ADDR_W - 1 : ADDR_B_W], ADDR_B_W'( 0 ) };
          op_pkt_o.low_burst_bits   <= low_burst_bits;
          op_pkt_o.start_offset     <= start_offset;
          op_pkt_o.end_offset       <= end_offset;
        end
      else
        if( ADDR_TYPE == "WORD" )
          op_pkt_o.word_addr    <= decoded_addr;
    end

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    wr_result_o <= 1'b0;
  else
    wr_result_o <= ( test_complete_state && test_complete_flg );

assign trans_en_state       = ( state == WRITE_ONLY_S ) ||
                              ( state == READ_ONLY_S  ) ||
                              ( state == WRITE_WORD_S ) ||
                              ( state == READ_WORD_S  );

assign cnt_en_state         = ( state == READ_ONLY_S  ) ||
                              ( state == WRITE_ONLY_S ) ||
                              ( state == READ_WORD_S  );

assign next_addr_stb        = ( cnt_en_state && ( !op_valid_o || cmd_accepted_stb ) );

assign test_complete_state  = ( state == END_TEST_S   ) || ( state == ERROR_CHECK_S );

assign cmd_accepted_stb     = ( op_valid_o && cmd_accept_ready_i );

assign low_burst_bits       = (ADDR_B_W + 1)'( burstcount_csr_reg[ADDR_B_W - 1 : 0] + decoded_addr[ADDR_B_W - 1 : 0] );

assign start_offset         = decoded_addr[ADDR_B_W - 1 : 0];

assign end_offset           = decoded_addr[ADDR_B_W - 1 : 0] + burstcount_csr_reg[ADDR_B_W - 1 : 0];

assign test_complete_flg    = ( !cmp_block_busy_i && !meas_block_busy_i && !trans_block_busy_i );

endmodule : control_block
