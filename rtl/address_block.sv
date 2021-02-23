import rtl_settings_pkg::*;

module address_block(
  input                             rst_i,
  input                             clk_i,

  input                             start_test_i,
  input         [2 : 1][31 : 0]     test_param_i,

  input                             next_addr_en_i,

  output logic  [ADDR_W - 1 : 0]    next_addr_o
);

addr_mode_t                           addr_mode;

logic         [ADDR_W - 1     : 0]    csr_fix_addr;

logic         [ADDR_W - 1     : 0]    fix_addr;
logic         [RND_ADDR_W - 1 : 0]    rnd_addr;  
logic         [ADDR_W - 1     : 0]    run_0;
logic         [ADDR_W - 1     : 0]    run_1;
logic         [ADDR_W - 1     : 0]    inc_addr;

logic                                 rnd_gen_bit;

generate
  if( ADDR_W <= 8 )
    begin
      localparam int RND_ADDR_W = 8;
      assign rnd_gen_bit   = ( rnd_addr[7] ^ rnd_addr[5] ^ rnd_addr[4] ^ rnd_addr[3] );
    end
  else
    if( ADDR_W <= 16 )
      begin
        localparam int RND_ADDR_W = 16;
        assign rnd_gen_bit   = ( rnd_addr[16] ^ rnd_addr[7] ^ rnd_addr[1] );
      end
    else
      if( ADDR_W <= 32 )
        begin
          localparam int RND_ADDR_W = 32;
          assign rnd_gen_bit   = ( rnd_addr[31] ^ rnd_addr[21] ^ rnd_addr[1] ^ rnd_addr[0] );
        end
endgenerate

always_ff @( posedge clk_i )
  if( addr_mode == FIX_ADDR )
    if( start_test_i )
      fix_addr <= csr_fix_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr <= '1;
  else
    if( addr_mode == RND_ADDR )
      if( next_addr_en_i )
        rnd_addr <= { rnd_addr[RND_ADDR_W - 2 : 0], rnd_gen_bit };

always_ff @( posedge clk_i )
  if( addr_mode == RUN_0_ADDR )
    if( start_test_i )
      run_0 <= { {(ADDR_W - 1){ 1'b1 }}, 1'b0 };
    else
      if( next_addr_en_i )
        run_0 <= { run_0[ADDR_W - 2 : 0], run_0[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode == RUN_1_ADDR )
    if( start_test_i )
      run_1 <= { {(ADDR_W - 1){ 1'b0 }}, 1'b1 };
    else
      if( next_addr_en_i )
        run_1 <= { run_1[ADDR_W - 2 : 0], run_1[ADDR_W - 1] };

always_ff @( posedge clk_i )
  if( addr_mode == INC_ADDR )
    if( start_test_i )
      inc_addr <= csr_fix_addr;
    else
      if( next_addr_en_i )
        inc_addr <= inc_addr + 1'b1;

always_comb
  case( addr_mode )
    FIX_ADDR    : next_addr_o = fix_addr;
    RND_ADDR    : next_addr_o = rnd_addr[ADDR_W - 1 : 0];
    RUN_0_ADDR  : next_addr_o = run_0;
    RUN_1_ADDR  : next_addr_o = run_1;
    INC_ADDR    : next_addr_o = inc_addr;
    default     : next_addr_o = ADDR_W'( 0 );
  endcase

//$cast( addr_mode, test_param_i[1][13 : 11] );
assign addr_mode    = addr_mode_t'( test_param_i[1][13 : 11] );

assign csr_fix_addr = test_param_i[2][ADDR_W - 1 : 0];

endmodule : address_block
