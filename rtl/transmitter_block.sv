import rtl_settings_pkg::*;

module transmitter_block( 
  input                               rst_i,
  input                               clk_i,

  // Address block interface
  input                               trans_valid_i,
  input         [ADDR_W - 1 : 0]      trans_addr_i,
  input                               trans_type_i,

  input                               start_test_i,
  input         [2 : 1] [31 : 0]      test_param_reg_i,
  
  output logic                        in_process_o,
  output logic                        trans_block_busy_o,

  // Compare block interface
  input                               error_check_i,

  output logic                        cmp_pkt_en_o,
  output cmp_pkt_t                    cmp_pkt_o,

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
  input logic                     start_off_en,
  input logic [ADDR_B_W - 1 : 0]  start_off,
  input logic                     end_off_en,
  input logic [ADDR_B_W - 1 : 0]  end_off
);
  for( int i = 0; i < DATA_B_W; i++ )
    case( { start_off_en, end_off_en } )
      0 : byteenable_ptrn[i] = 1'b1;
      1 : byteenable_ptrn[i] = ( i <= end_off   );
      2 : byteenable_ptrn[i] = ( i >= start_off );
      3 : byteenable_ptrn[i] = ( i >= start_off ) && ( i <= end_off );
      default : byteenable_ptrn[i] = 1'bX;
    endcase
endfunction : byteenable_ptrn

// csr registers casting
data_mode_t                 data_mode;
test_mode_t                 test_mode;

logic [AMM_BURST_W - 1 : 0] burstcount_reg;
logic [7 : 0]               data_ptrn_reg;
logic                       rnd_data_gen_bit;
logic [7 : 0]               rnd_data_reg = 8'hFF;
logic [AMM_BURST_W - 1 : 0] burstcount_exp;

assign data_ptrn      = test_param_reg_i[2][7 : 0];
assign burstcount_reg = test_param_reg_i[1][AMM_BURST_W - 2 : 0];
assign data_mode      = data_mode_t'( test_param_reg_i[1][12] );
assign test_mode      = test_mode_t'( test_param_reg_i[1][17 : 16] );

// variables declaration
logic [AMM_BURST_W - 1 : 0] burst_cnt;
logic                       wr_unit_stb;
logic                       start_stb;
logic                       last_word_flag;
logic                       low_burst_en_flg;
logic                       high_burst_en_flg;
logic                       pkt_storage_valid;

struct packed{
  logic [AMM_ADDR_W - 1 : 0]  start_addr;
  logic                       trans_type;
  logic [ADDR_B_W - 1 : 0]    start_off;
  logic [ADDR_B_W - 1 : 0]    end_off;
  logic [AMM_BURST_W - 1 : 0] words_count;
} storage_struct, cur_struct;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid <= 1'b0;
  else
    if( error_check_i )
      storage_valid <= 1'b0;
    else
      if( in_process_o )
        storage_valid <= trans_valid_i;

always_ff @( posedge clk_i )
  if( start_stb )
    cur_struct <= storage_struct;

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address
      if( ( AMM_BURST_W - 1 ) > ADDR_B_W )
        begin : less_than_burst_bits

          assign low_addr_bits = ( ( ADDR_B_W + 1 )'( burstcount_reg[AMM_BURST_W - 2 : 0] + trans_addr_i[ADDR_B_W - 1 : 0] ) );

          always_ff @( posedge clk_i )
            if( start_test_i )
              high_burst_en_flg <= ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] != 0 );

          always_ff @( posedge clk_i )
            if( in_process_o && op_valid_i )
              low_burst_en_flg <= ( low_addr_bits >= DATA_B_W );

          always_ff @( posedge clk_i )
            if( start_stb )
              if( storage_struct.trans_type )
                byteenable_o <= '1;
              else
                byteenable_o <= byteenable_ptrn( 1'b1, storage_struct.start_offset, ( high_burst_en_flg || low_burst_en_flg ),  storage_struct.end_offset );
            else
              if( wr_unit_stb )
                byteenable_o <= byteenable_ptrn( 1'b0, cur_struct.start_offset, last_word_flag, cur_struct.end_offset );

            assign burstcount_exp = ( low_burst_en_flg ) ?  ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] + 2'd2 ) :
                                                            ( burstcount_reg[AMM_BURST_W - 2 : ADDR_B_W] + 2'd1 );
        end
      else
        begin : some_common_expressions
          if( ( AMM_BURST_W - 1 ) <= ADDR_B_W )
            begin : more_than_burst_width

              logic [ADDR_B_W - 1 : 0] low_addr_bits;

              assign low_addr_bits = ( burstcount_reg[AMM_BURST_W - 2 : 0] + trans_addr_i[ADDR_B_W - 1 : 0] );

              always_ff @( posedge clk_i )
                if( in_process_o && op_valid_i )
                  low_burst_en_flg <= ( low_addr_bits >= DATA_B_W );

              assign burstcount_exp = ( low_burst_en_flg ) ?  ( AMM_BURST_W'( 2 ) ):
                                                              ( AMM_BURST_W'( 1 ) );


              always_ff @( posedge clk_i )
                if( start_stb )
                  if( storage_struct.pkt_type )
                    byteenable_o <= '1;
                  else
                    byteenable_o <= byteenable_ptrn( 1'b1, 1'b1, storage_struct.start_offset, storage_struct.end_offset );
            end
          else
            if( AMM_BURST_W <= ADDR_B_W )
              begin : much_more_than_burst_width

                logic [ADDR_B_W - 1 : 0] low_addr_bits;

                assign low_addr_bits  = ( burstcount_reg[AMM_BURST_W - 2 : 0] + trans_addr_i[ADDR_B_W - 1 : 0] );

                assign burstcount_exp = AMM_BURST_W'( 1 );

                always_ff @( posedge clk_i )
                  if( start_stb )
                    if( storage_struct.pkt_type )
                      byteenable_o <= '1;
                    else
                      byteenable_o <= byteenable_ptrn( 1'b1, 1'b1, storage_struct.start_offset, storage_struct.end_offset );

              end
        end

      logic [DATA_B_W - 1 : 0]            byteenable_exp;

      always_ff @( posedge clk_i )
        if( in_process_o && op_valid_i )
          begin
            storage_struct.start_addr         <= { trans_addr_i[ADDR_W - 1 : ADDR_B_W], ADDR_B_W'( 0 ) };
            storage_struct.trans_type   <= trans_type_i;
            storage_struct.start_offset <= trans_addr_i [ADDR_B_W - 1 : 0];
            storage_struct.end_offset   <= low_addr_bits[ADDR_B_W - 1 : 0];
          end

      always_ff @( posedge clk_i )
        if( start_stb )
          address_o <= { storage_struct.start_addr[ADDR_W - 1 : ADDR_B_W], ADDR_B_W'( 0 ) };

      always_ff @( posedge clk_i )
        if( start_stb )
          if( storage_struct.pkt_type )
            burstcount_o <= burstcount_exp;
          else
            burstcount_o <= burstcount_reg + 1'b1;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= AMM_BURST_W'( 0 );
        else
          if( start_stb )
            burst_cnt <= burstcount_exp;
          else
            if( wr_unit_stb )
              burst_cnt <= burst_cnt - 1'b1;

    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address
        
        always_ff @( posedge clk_i )
          if( in_process_o && op_valid_i )
            begin
              storage_struct.start_addr         <= trans_addr_i;
              storage_struct.trans_type   <= trans_type_i;
            end

        always_ff @( posedge clk_i )
          if( start_test_i )
            high_burst_en_flg <= ( burstcount_reg != 0 );

        always_ff @( posedge clk_i )
          if( start_stb )
            address_o <= storage_struct.start_addr;

        always_ff @( posedge clk_i )
          if( start_stb )
            burstcount_o <= burstcount_reg + 1'b1;

        always_ff @( posedge clk_i )
          if( start_stb )
            burst_cnt <= burstcount_reg + 1'b1;
          else
            if( wr_unit_stb )
              burst_cnt <= burst_cnt - 1'b1;

        assign byteenable_o   = '1;

      end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    in_process_o <= 1'b0;
  else
    if( start_stb )
      in_process_o <= 1'b1;
    else
      if( in_process_o )
        if( cur_struct.trans_type )
          in_process_o <= waitrequest_i;
        else
          in_process_o <= !( last_word_flag && !waitrequest_i );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else
    if( start_stb && ( !storage_struct.trans_type ) )
      write_o <= 1'b1;
    else
      if( last_word_flag && !waitrequest_i )
        write_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_o <= 1'b0;
  else
    if( start_stb && storage_struct.trans_type )
      read_o <= 1'b1;
    else
      if( !waitrequest_i )
        read_o <= 1'b0;

always_ff @( posedge clk_i )
  if( start_stb )
    last_word_flag <= !( high_burst_en_flg || low_burst_en_flg );
  else
    if( wr_unit_stb )
      last_word_flag <= ( burst_cnt == 2 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data_reg <= 8'hFF;
  else
    if( data_mode == RND_DATA )
      if( start_stb || wr_unit_stb )
        rnd_data_reg <= { rnd_data_reg[6 : 0], data_gen_bit };

always_ff @( posedge clk_i )
  if( start_stb || wr_unit_stb )
    if( data_mode == RND_DATA )
      writedata_o <= { DATA_B_W{ rnd_data_reg  } };
    else
      writedata_o <= { DATA_B_W{ data_ptrn_reg } };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_pkt_en_o <= 1'b0;
  else
    if( test_mode == WRITE_AND_CHECK )
      cmp_pkt_en_o <= ( start_stb && !storage_struct.trans_type );
    else
      cmp_pkt_en_o <= 1'b0;

always_ff @( posedge clk_i )
  if( test_mode == WRITE_AND_CHECK )
    if( start_stb && !storage_struct.trans_type )
      begin
        cmp_pkt_o.start_addr        <= storage_struct.word_addr;
        cmp_pkt_o.words_count <= burstcount_exp;
        cmp_pkt_o.start_off   <= storage_struct.start_off;
        cmp_pkt_o.end_off     <= storage_struct.end_off;
        cmp_pkt_o.data_mode   <= data_mode;
        if( data_mode == RND_DATA )
          cmp_pkt_o.data_ptrn <= rnd_data_reg;
        else
          cmp_pkt_o.data_ptrn <= data_ptrn_reg;
      end

assign data_gen_bit = ( rnd_data_reg[6] ^ rnd_data_reg[1] ^ rnd_data_reg[0] );
assign wr_unit_stb  = ( write_o && ( !waitrequest_i ) );
assign start_stb    = ( !in_process_o && pkt_storage_valid );

endmodule : transmitter_block
