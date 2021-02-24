import rtl_settings_pkg::*;

module transmitter_block( 
  input                                 rst_i,
  input                                 clk_i,

  input         [3 : 1] [31 : 0]        test_param_i,

  // Control block interface
  input                                 trans_valid_i,
  input         [ADDR_W - 1 : 0]        trans_addr_i,
  input                                 trans_type_i,
  
  output logic                          trans_process_o,
  output logic                          trans_busy_o,

  // Compare block interface
  input                                 cmp_error_i,

  output logic                          cmp_en_o,
  output cmp_struct_t                   cmp_struct_o,

  // AMM_master interface
  input                                 readdatavalid_i,
  input         [AMM_DATA_W - 1   : 0]  readdata_i,
  input                                 waitrequest_i,

  output logic  [AMM_ADDR_W - 1   : 0]  address_o,
  output logic                          read_o,
  output logic                          write_o,
  output logic  [AMM_DATA_W - 1   : 0]  writedata_o,
  output logic  [AMM_BURST_W - 1  : 0]  burstcount_o,
  output logic  [DATA_B_W - 1     : 0]  byteenable_o
);

data_mode_t                 data_mode;
test_mode_t                 test_mode;

logic [AMM_BURST_W - 2 : 0] burstcount;

logic                       data_gen_bit;
logic [7 : 0]               data_ptrn;
logic [7 : 0]               rnd_data = 8'hFF;

logic                       rnd_data_en;
logic                       burst_en;

logic [AMM_BURST_W - 2 : 0] burstcount_exp;
logic [AMM_BURST_W - 2 : 0] burst_cnt;

logic                       wr_unit_stb;
logic                       start_stb;

logic                       last_unit_flag;
logic                       storage_valid;

cmp_struct_t                storage_struct;
cmp_struct_t                cur_struct;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    trans_process_o <= 1'b0;
  else
    if( start_stb )
      trans_process_o <= 1'b1;
    else
      if( trans_process_o  && !waitrequest_i )
        if( cur_struct.trans_type )
          trans_process_o <= 1'b0;
        else
          if( last_unit_flag )
            trans_process_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid <= 1'b0;
  else
    if( cmp_error_i )
      storage_valid <= 1'b0;
    else
      if( !trans_process_o )
        storage_valid <= trans_valid_i;

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address
      //-----------------------------------------------------------------------------------------------------------------------
      always_comb
        if( ( AMM_BURST_W - 1 ) > ADDR_B_W )
          if( burst_en )
            burstcount_exp = ( burstcount[AMM_BURST_W - 2 : ADDR_B_W] + 1'b1  );
          else
            burstcount_exp = ( burstcount[AMM_BURST_W - 2 : ADDR_B_W]         );
        else
          if( burst_en )
            burstcount_exp = AMM_BURST_W'( 1 );
          else
            burstcount_exp = AMM_BURST_W'( 0 );

      always_ff @( posedge clk_i )
        if( trans_valid_i && ( !trans_process_o ) )
          begin
            storage_struct.start_addr <= ( trans_addr_i[ADDR_W - 1 : ADDR_B_W] << ADDR_B_W );
            storage_struct.trans_type <= trans_type_i;
            storage_struct.start_off  <= trans_addr_i[ADDR_B_W - 1 : 0];
            storage_struct.end_off    <= ADDR_B_W'( burstcount + trans_addr_i[ADDR_B_W - 1 : 0] );
          end

      always_ff @( posedge clk_i )
        if( start_stb )
          begin
            cur_struct.start_addr   <= storage_struct.start_addr;
            cur_struct.start_off    <= storage_struct.start_off;
            cur_struct.end_off      <= storage_struct.end_off;
            cur_struct.words_count  <= burstcount_exp;
            cur_struct.data_mode    <= data_mode;
            if( data_mode == RND_DATA )
              cur_struct.data_ptrn  <= rnd_data;
            else
              cur_struct.data_ptrn  <= data_ptrn;
          end

      always_ff @( posedge clk_i )
        if( trans_valid_i && ( !trans_process_o ) )
          burst_en <= ( ( burstcount + trans_addr_i[ADDR_B_W - 1 : 0] ) >= DATA_B_W );

      always_ff @( posedge clk_i )
        if( start_stb || wr_unit_stb )
          if( wr_unit_stb )
            byteenable_o <= byteenable_ptrn( 1'b0, cur_struct.start_off,      last_unit_flag, cur_struct.end_off      );
          else
            if( storage_struct.trans_type )
              byteenable_o <= '1;
            else
              byteenable_o <= byteenable_ptrn( 1'b1, storage_struct.start_off,  ( !burst_en ),  storage_struct.end_off  );

      always_ff @( posedge clk_i )
        if( start_stb )
          if( storage_struct.trans_type )
            burstcount_o <= burstcount_exp;
          else
            burstcount_o <= burstcount + 1'b1;

      always_ff @( posedge clk_i, posedge rst_i )
        if( rst_i )
          burst_cnt <= ( AMM_BURST_W - 1 )'( 0 );
        else
          if( start_stb )
            burst_cnt <= burstcount_exp;
          else
            if( wr_unit_stb )
              burst_cnt <= burst_cnt - 1'b1;

      always_ff @( posedge clk_i )
        if( start_stb )
          last_unit_flag <= ( !burst_en );
        else
          if( wr_unit_stb )
            last_unit_flag <= ( burst_cnt == 1 );
      //-----------------------------------------------------------------------------------------------------------------------
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address
        //-----------------------------------------------------------------------------------------------------------------------
        always_ff @( posedge clk_i )
          if( trans_valid_i && ( !trans_process_o ) )
            begin
              storage_struct.start_addr   <= trans_addr_i;
              storage_struct.trans_type   <= trans_type_i;
            end

        always_ff @( posedge clk_i )
          if( start_stb )
            begin
              cur_struct.start_addr   <= storage_struct.start_addr;
              cur_struct.words_count  <= burstcount;
              cur_struct.data_mode    <= data_mode;
              if( data_mode == RND_DATA )
                cur_struct.data_ptrn  <= rnd_data;
              else
                cur_struct.data_ptrn  <= data_ptrn;
            end

        always_ff @( posedge clk_i )
          if( trans_valid_i && ( !trans_process_o ) )
            burst_en <= ( burstcount != 0 );

        always_ff @( posedge clk_i )
          if( start_stb )
            burst_cnt <= burstcount;
          else
            if( wr_unit_stb )
              burst_cnt <= burst_cnt - 1'b1;

        always_ff @( posedge clk_i )
          if( start_stb )
            last_unit_flag <= ( !burst_en );
          else
            if( wr_unit_stb )
              last_unit_flag <= ( burst_cnt == 1 );

        always_ff @( posedge clk_i )
          if( start_stb )
            burstcount_o <= burstcount + 1'b1;

        assign byteenable_o   = '1;
        //-----------------------------------------------------------------------------------------------------------------------
      end
endgenerate

always_ff @( posedge clk_i )
  if( start_stb )
    address_o <= storage_struct.start_addr;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else
    if( start_stb && ( !storage_struct.trans_type ) )
      write_o <= 1'b1;
    else
      if( last_unit_flag && !waitrequest_i )
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
  if( start_stb || wr_unit_stb )
    if( data_mode == RND_DATA )
      writedata_o <= { DATA_B_W{ rnd_data  } };
    else
      writedata_o <= { DATA_B_W{ data_ptrn } };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data <= '1;
  else
    if( rnd_data_en )
      rnd_data <= { rnd_data[6 : 0], data_gen_bit };

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    cmp_en_o <= 1'b0;
  else
    if( test_mode == WRITE_AND_CHECK )
      cmp_en_o <= ( start_stb && !storage_struct.trans_type );
    else
      cmp_en_o <= 1'b0;

assign rnd_data_en = ( data_mode == RND_DATA ) && ( start_stb || wr_unit_stb );

assign data_ptrn    = test_param_i[3][7 : 0              ];
assign burstcount   = test_param_i[1][AMM_BURST_W - 2 : 0];

assign data_mode    = data_mode_t'( test_param_i[1][12]      );
assign test_mode    = test_mode_t'( test_param_i[1][17 : 16] );

assign wr_unit_stb  = ( write_o       && ( !waitrequest_i )   );
assign start_stb    = ( storage_valid && ( !trans_process_o ) );

assign data_gen_bit = ( rnd_data[6] ^ rnd_data[1] ^ rnd_data[0] );

assign trans_busy_o = ( trans_process_o || storage_valid );

assign cmp_struct_o = cur_struct;

endmodule : transmitter_block
