import rtl_settings_pkg::*;

module transmitter_block( 
  input                               rst_i,
  input                               clk_i,

  // Address block interface
  input                               op_valid_i,
  input  trans_pkt_t               op_pkt_i,

  input         [2 : 1] [31 : 0]      test_param_reg_i,
  
  output logic                        cmd_accept_ready_o,
  output logic                        trans_block_busy_o,

  // Compare block interface
  input                               error_check_i,

  output logic                        cmp_pkt_en_o,
  output cmp_pkt_t                 cmp_pkt_o,

  // Avalon-MM output interface
  input                               readdatavalid_i,
  input         [AMM_DATA_W - 1 : 0]  readdata_i,
  input                               waitrequest_i,

  output logic  [AMM_ADDR_W - 1 : 0]  address_o,
  output logic                        read_o,
  output logic                        write_o,
  output logic  [AMM_DATA_W - 1 : 0]  writedata_o,
  output logic  [AMM_BURST_W - 1 : 0] burstcount_o,
  output logic  [DATA_B_W - 1 : 0]    byteenable_o
);

function automatic logic [DATA_B_W - 1 : 0] byteenable_ptrn(
  input logic                     start_flag,
  input logic                     end_flag,
  input logic [ADDR_B_W - 1 : 0]  start_offset,
  input logic [ADDR_B_W - 1 : 0]  end_offset
);
  for( int i = 0; i < DATA_B_W; i++ )
    case( { start_flag, end_flag } )
      1 : byteenable_ptrn[i] = ( i <= end_offset   );
      2 : byteenable_ptrn[i] = ( i >= start_offset );
      3 : byteenable_ptrn[i] = ( i >= start_offset ) && ( i <= end_offset );
      default : byteenable_ptrn[i] = 1'bX;
    endcase
endfunction : byteenable_ptrn

// csr registers casting
data_mode_t                 data_ptrn_mode_reg;
test_mode_t                 test_mode_reg;

logic [AMM_BURST_W - 1 : 0] burstcount_reg;
logic [7 : 0]               data_ptrn_reg;
logic                       rnd_data_gen_bit;
logic [7 : 0]               rnd_data_reg;
logic [AMM_BURST_W - 1 : 0] burstcount_exp;

assign data_ptrn_reg      = test_param_reg_i[2][7 : 0];
assign burstcount_reg     = test_param_reg_i[1][AMM_BURST_W - 2 : 0];
assign data_ptrn_mode_reg = data_mode_t'( test_param_reg_i[1][12] );
assign test_mode_reg      = test_mode_t'( test_param_reg_i[1][17 : 16] );

// variables declaration
logic [AMM_BURST_W - 1 : 0] burst_cnt;
logic                       wr_unit_complete_stb;
logic                       start_trans_stb;
logic                       last_trans_flg;
cmp_pkt_t                storage_op_pkt;
cmp_pkt_t                cur_op_pkt;
logic                       low_burst_en_flg;
logic                       high_burst_en_flg;
logic                       pkt_storage_valid;

// first stage -- analyzing of packet, calculating main expression
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    pkt_storage_valid <= 1'b0;
  else
    if( error_check_i )
      pkt_storage_valid <= 1'b0;
    else
      if( cmd_accept_ready_o )
        pkt_storage_valid <= op_valid_i;

always_ff @( posedge clk_i )
  if( cmd_accept_ready_o && op_valid_i )
    if( ADDR_TYPE == "BYTE" )
      begin
        storage_op_pkt.pkt_type     <= op_pkt_i.pkt_type;
        storage_op_pkt.word_addr    <= op_pkt_i.word_addr;
        storage_op_pkt.start_mask   <= byteenable_ptrn( 1'b1, 1'b0, op_pkt_i.start_offset, op_pkt_i.end_offset );
        storage_op_pkt.end_mask     <= byteenable_ptrn( 1'b0, 1'b1, op_pkt_i.start_offset, op_pkt_i.end_offset );
        storage_op_pkt.middle_mask  <= byteenable_ptrn( 1'b1, 1'b1, op_pkt_i.start_offset, op_pkt_i.end_offset );
      end
    else
      if( ADDR_TYPE == "WORD" )
        begin
          storage_op_pkt.pkt_type   <= op_pkt_i.pkt_type;
          storage_op_pkt.word_addr  <= op_pkt_i.word_addr;
        end

always_ff @( posedge clk_i )
  if( cmd_accept_ready_o && op_valid_i )
    if( ADDR_TYPE == "BYTE" )
      high_burst_en_flg <= ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] != 0 );
    else
      if( ADDR_TYPE == "WORD" )
        high_burst_en_flg <= ( burstcount_reg != 0 );

always_ff @( posedge clk_i )
  if( cmd_accept_ready_o && op_valid_i )
    low_burst_en_flg <= ( op_pkt_i.low_burst_bits >= DATA_B_W );

// second stage -- transmitting packet through AMM interface
always_ff @( posedge clk_i )
  if( start_trans_stb )
    cur_op_pkt <= storage_op_pkt;

always_ff @( posedge clk_i )
  if( start_trans_stb )
    address_o <= 32'( storage_op_pkt.word_addr );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else
    if( start_trans_stb && !storage_op_pkt.pkt_type )
      write_o <= 1'b1;
    else
      if( last_trans_flg && wr_unit_complete_stb )
        write_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_o <= 1'b0;
  else
    if( start_trans_stb && storage_op_pkt.pkt_type )
      read_o <= 1'b1;
    else
      if( !waitrequest_i )
        read_o <= 1'b0;

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address

      logic [DATA_B_W - 1 : 0]            byteenable_exp;

      always_ff @( posedge clk_i )
        if( start_trans_stb )
          if( storage_op_pkt.pkt_type )
            burstcount_o <= burstcount_exp;
          else
            burstcount_o <= burstcount_reg + 1'b1;

      always_ff @( posedge clk_i )
        if( start_trans_stb )
          begin
            if( storage_op_pkt.pkt_type )
              byteenable_o <= '1;
            else
              if( high_burst_en_flg || low_burst_en_flg )
                byteenable_o <= storage_op_pkt.start_mask;
              else
                byteenable_o <= storage_op_pkt.middle_mask;
          end
        else
          if( wr_unit_complete_stb )
            byteenable_o <= byteenable_exp;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else
          if( start_trans_stb )
            burst_cnt <= burstcount_exp;
          else
            if( wr_unit_complete_stb )
              burst_cnt <= burst_cnt - 1'b1;

      assign burstcount_exp = ( low_burst_en_flg ) ?  ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] + 2'd2 ) :
                                                      ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] + 2'd1 );

      assign byteenable_exp = ( burst_cnt == 2 ) ? ( cur_op_pkt.end_mask  ) :
                                                   ( '1                   );
                                                  
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address
        
        always_ff @( posedge clk_i )
          if( start_trans_stb )
            burstcount_o <= burstcount_exp;

        always_ff @( posedge clk_i, posedge rst_i )
          if( rst_i )
            burst_cnt <= AMM_BURST_W'( 0 );
          else
            if( start_trans_stb )
              burst_cnt <= burstcount_reg + 1'b1;
            else
              if( wr_unit_complete_stb )
                burst_cnt <= burst_cnt - 1'b1;

        assign byteenable_o   = '1;
        assign burstcount_exp = burstcount_reg + 1'b1;

      end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    last_trans_flg <= 1'b0;
  else
    if( start_trans_stb )
      last_trans_flg <= !( high_burst_en_flg || low_burst_en_flg );
    else
      if( wr_unit_complete_stb )
        last_trans_flg <= ( burst_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else
    if( data_ptrn_mode_reg == RND_DATA )
      if( start_trans_stb || wr_unit_complete_stb )
        rnd_data_reg <= { rnd_data_reg[6 : 0], rnd_data_gen_bit };

always_ff @( posedge clk_i )
  if( start_trans_stb || wr_unit_complete_stb )
    if( data_ptrn_mode_reg == RND_DATA )
      writedata_o <= { DATA_B_W{ rnd_data_reg       } };
    else
      writedata_o <= { DATA_B_W{ data_ptrn_reg  } };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmd_accept_ready_o <= 1'b0;
  else
    if( cmd_accept_ready_o )
      cmd_accept_ready_o <= ( !pkt_storage_valid );
    else
      if( read_o )
        cmd_accept_ready_o <= ( !waitrequest_i );
      else
        if( write_o )
          cmd_accept_ready_o <= ( last_trans_flg && !waitrequest_i );

// interaction with compare block
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_pkt_en_o <= 1'b0;
  else
    if( test_mode_reg == WRITE_AND_CHECK )
      cmp_pkt_en_o <= ( start_trans_stb && !storage_op_pkt.pkt_type );
    else
      cmp_pkt_en_o <= 1'b0;

always_ff @( posedge clk_i )
  if( test_mode_reg == WRITE_AND_CHECK )
    if( start_trans_stb && !storage_op_pkt.pkt_type )
      begin
        cmp_pkt_o.word_addr       <= storage_op_pkt.word_addr;
        cmp_pkt_o.word_count      <= burstcount_exp;
        cmp_pkt_o.start_mask      <= storage_op_pkt.start_mask;
        cmp_pkt_o.end_mask        <= storage_op_pkt.end_mask;
        cmp_pkt_o.middle_mask     <= storage_op_pkt.middle_mask;
        cmp_pkt_o.data_ptrn_mode  <= data_ptrn_mode_reg;
        if( data_ptrn_mode_reg == RND_DATA )
          cmp_pkt_o.data_ptrn <= rnd_data_reg;
        else
          cmp_pkt_o.data_ptrn <= data_ptrn_reg;
      end

assign rnd_data_gen_bit     = ( rnd_data_reg[6] ^ rnd_data_reg[1] ^ rnd_data_reg[0] );
assign wr_unit_complete_stb = ( write_o && !waitrequest_i               );
assign start_trans_stb      = ( cmd_accept_ready_o && pkt_storage_valid && !error_check_i );
assign trans_block_busy_o   = ( !cmd_accept_ready_o );

endmodule : transmitter_block
