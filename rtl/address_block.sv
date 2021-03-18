import rtl_settings_pkg::*;

module address_block(
  input                                                   rst_i,
  input                                                   clk_i,

  input                                                   test_start_i,
  input         [CSR_SET_ADDR : CSR_TEST_PARAM][31 : 0]   test_param_i,

  input                                                   next_addr_en_i,

  output logic  [ADDR_W - 1 : 0]                          next_addr_o
);

function automatic int addr_width_calc( int addr_width );
  if( addr_width <= 8 )
    return( 8 );
  else
    if( addr_width <= 16 )
      return( 16 );
    else
      if( addr_width <= 32 )
        return( 32 );
endfunction : addr_width_calc

localparam RND_ADDR_W = addr_width_calc( ADDR_W );

addr_mode_t                       addr_mode;

logic         [ADDR_W - 1 : 0]    fix_addr;
logic         [ADDR_W - 1 : 0]    run_0;
logic         [ADDR_W - 1 : 0]    run_1;
logic         [ADDR_W - 1 : 0]    inc_addr;

logic                             fix_addr_en;
logic                             rnd_addr_en;
logic                             run_0_en;
logic                             run_1_en;
logic                             inc_addr_en;

logic       [RND_ADDR_W - 1 : 0]  rnd_addr = '1;
logic                             rnd_gen_bit;

generate
  if( RND_ADDR_W == 8 )
    begin
      assign rnd_gen_bit = ( rnd_addr[7] ^ rnd_addr[1] ^ 1'b1 );
    end
  else
    if( RND_ADDR_W == 16 )
      begin
        assign rnd_gen_bit = ( rnd_addr[15] ^ rnd_addr[1] ^ 1'b1 );
      end
    else
      if( RND_ADDR_W == 32 )
        begin
          assign rnd_gen_bit = ( rnd_addr[31] ^ rnd_addr[3] ^ 1'b1 );
        end
endgenerate

always_ff @( posedge clk_i )
  if( fix_addr_en )
    fix_addr <= test_param_i[CSR_SET_ADDR][ADDR_W - 1 : 0];

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_addr <= '1;
  else
    if( rnd_addr_en )
      rnd_addr <= { rnd_addr[RND_ADDR_W - 2 : 0], rnd_gen_bit };


always_ff @( posedge clk_i )
  if( run_0_en )
    if( next_addr_en_i )
      run_0 <= { run_0[ADDR_W - 2 : 0], run_0[ADDR_W - 1] };
    else
      run_0 <= '1 - 1'b1; //{ {(ADDR_W - 1){ 1'b1 }}, 1'b0 };


always_ff @( posedge clk_i )
  if( run_1_en )
    if( next_addr_en_i )
      run_1 <= { run_1[ADDR_W - 2 : 0], run_1[ADDR_W - 1] };
    else
      run_1 <= '0 + 1'b1; //{ {(ADDR_W - 1){ 1'b0 }}, 1'b1 };


always_ff @( posedge clk_i )
  if( inc_addr_en )
    if( next_addr_en_i )
      inc_addr <= inc_addr + 1'b1;
    else
      inc_addr <= test_param_i[CSR_SET_ADDR][ADDR_W - 1 : 0];

always_comb
  case( addr_mode )
    FIX_ADDR    : next_addr_o = fix_addr;
    RND_ADDR    : next_addr_o = rnd_addr[ADDR_W - 1 : 0];
    RUN_0_ADDR  : next_addr_o = run_0;
    RUN_1_ADDR  : next_addr_o = run_1;
    INC_ADDR    : next_addr_o = inc_addr;
    default     : next_addr_o = ADDR_W'( 0 );
  endcase

assign addr_mode    = addr_mode_t'( test_param_i[CSR_TEST_PARAM][13 : 11] );

assign fix_addr_en  = ( addr_mode == FIX_ADDR   ) && test_start_i;
assign rnd_addr_en  = ( addr_mode == RND_ADDR   ) && next_addr_en_i;
assign run_0_en     = ( addr_mode == RUN_0_ADDR ) && ( test_start_i || next_addr_en_i );
assign run_1_en     = ( addr_mode == RUN_1_ADDR ) && ( test_start_i || next_addr_en_i );
assign inc_addr_en  = ( addr_mode == INC_ADDR   ) && ( test_start_i || next_addr_en_i );

endmodule : address_block
