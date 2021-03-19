import rtl_settings_pkg::*;

module transmitter_block( 
  input                                                   rst_i,
  input                                                   clk_i,

  // CSR block interface
  input         [CSR_SET_DATA : CSR_TEST_PARAM] [31 : 0]  test_param_i,

  // Control block interface
  input                                                   trans_valid_i,
  input         [ADDR_W - 1 : 0]                          trans_addr_i,
  input                                                   trans_type_i,
  
  output logic                                            trans_ready_o,
  output logic                                            trans_busy_o,

  // Compare block interface
  input                                                   cmp_error_i,

  output logic                                            cmp_en_o,
  output cmp_struct_t                                     cmp_struct_o,

  // AMM_master interface
  input                                                   waitrequest_i,

  output logic  [AMM_ADDR_W - 1   : 0]                    address_o,
  output logic                                            read_o,
  output logic                                            write_o,
  output logic  [AMM_DATA_W - 1   : 0]                    writedata_o,
  output logic  [AMM_BURST_W - 1  : 0]                    burstcount_o,
  output logic  [DATA_B_W - 1     : 0]                    byteenable_o
);

data_mode_t                           data_mode;
test_mode_t                           test_mode;

logic         [AMM_BURST_W - 2 : 0]   burstcount;
logic         [AMM_BURST_W - 2 : 0]   burstcount_exp;
logic         [AMM_BURST_W - 2 : 0]   burst_cnt;

logic         [7 : 0]                 data_ptrn;
logic         [7 : 0]                 rnd_data = 8'hFF;
logic                                 data_gen_bit;

logic                                 writedata_en;
logic                                 storage_burst_en;

logic                                 in_process;

logic                                 wr_unit_stb;
logic                                 start_allowed;
logic                                 start_stb;

logic                                 last_transaction;
logic                                 last_transaction_stb;
logic                                 storage_valid;

cmp_struct_t                          storage_struct;
cmp_struct_t                          cur_struct;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    storage_valid <= 1'b0;
  else
    if( cmp_error_i )
      storage_valid <= 1'b0;
    else
      if( trans_ready_o )
        storage_valid <= trans_valid_i;

always_ff @( posedge clk_i )
  if( start_stb )
    if( storage_struct.trans_type )
      last_transaction <= 1'b1;
    else
      last_transaction <= ( !storage_burst_en );
  else
    if( wr_unit_stb )
      last_transaction <= ( burst_cnt == 1 );

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    in_process <= 1'b0;
  else
    if( start_stb )
      in_process <= 1'b1;
    else
      if( last_transaction && !waitrequest_i )
        in_process <= 1'b0;

generate
  if( ADDR_TYPE == "BYTE" )
    begin : byte_address

      localparam int BURST_SUM_W = ( ( AMM_BURST_W - 1 ) > ADDR_B_W ) ? ( AMM_BURST_W   ):
                                                                        ( ADDR_B_W + 1  );

      logic                           low_bits_burst_en;
      logic   [BURST_SUM_W - 1 : 0]   burst_units_sum;

      if( ( AMM_BURST_W - 1 ) > ADDR_B_W )
        begin
          assign burst_units_sum = ( trans_addr_i[ADDR_B_W - 1 : 0] + burstcount[ADDR_B_W - 1 : 0] );

          always_comb
            if( storage_burst_en && low_bits_burst_en )
              burstcount_exp = ( burstcount[AMM_BURST_W - 2 : ADDR_B_W] + 1'b1  );
            else
              burstcount_exp = ( burstcount[AMM_BURST_W - 2 : ADDR_B_W]         );
        end
      else
        begin
          assign burst_units_sum = ( trans_addr_i[ADDR_B_W - 1 : 0] + burstcount[AMM_BURST_W - 2 : 0] );

          always_comb
            if( low_bits_burst_en )
              burstcount_exp = (AMM_BURST_W - 2)'( 1 );
            else
              burstcount_exp = (AMM_BURST_W - 2)'( 0 );
        end

      always_ff @( posedge clk_i )
        if( trans_valid_i && trans_ready_o )
          begin
            storage_burst_en  <= ( trans_addr_i[ADDR_B_W - 1 : 0] + burstcount  >= DATA_B_W );
            low_bits_burst_en <= burst_units_sum[ADDR_B_W];
          end

     always_ff @( posedge clk_i )
        if( trans_valid_i && trans_ready_o )
          begin
            storage_struct.trans_type <= trans_type_i;
            storage_struct.start_addr <= trans_addr_i[ADDR_W   - 1 : ADDR_B_W];
            storage_struct.start_off  <= trans_addr_i[ADDR_B_W - 1 :        0];
            storage_struct.end_off    <= ADDR_B_W'( trans_addr_i[ADDR_B_W - 1 : 0] + burstcount );
          end
      
      always_ff @( posedge clk_i )
        if( start_stb )
          burst_cnt <= burstcount_exp;
        else
          if( wr_unit_stb )
            burst_cnt <= burst_cnt - 1'b1;

      always_ff @( posedge clk_i )
        if( start_stb )
          cur_struct.end_off  <= storage_struct.end_off;

      always_comb
        begin
          cmp_struct_o.start_addr   = storage_struct.start_addr;
          cmp_struct_o.data_mode    = data_mode;
          cmp_struct_o.start_off    = storage_struct.start_off;
          cmp_struct_o.end_off      = storage_struct.end_off;
          cmp_struct_o.words_count  = burstcount_exp;
          if( data_mode == RND_DATA )
            cmp_struct_o.data_ptrn  = rnd_data;
          else
            cmp_struct_o.data_ptrn  = data_ptrn;
        end

      always_ff @( posedge clk_i )
        if( start_stb )
          burstcount_o <= burstcount_exp + 1'b1;

      always_ff @( posedge clk_i )
        if( start_stb )
          address_o <= ( storage_struct.start_addr << ADDR_B_W );

      always_ff @( posedge clk_i )
        if( start_stb || wr_unit_stb )
          if( start_stb )
            if( storage_struct.trans_type )
              byteenable_o <= '1;
            else
              byteenable_o <= byteenable_ptrn( 1'b1, storage_struct.start_off,  ( !storage_burst_en ),  storage_struct.end_off );
          else
            byteenable_o <= byteenable_ptrn( 1'b0, cur_struct.start_off,  ( burst_cnt == 1 ),  cur_struct.end_off );

    end
  else
    if( ADDR_TYPE == "WORD" )
      begin : word_address

        always_ff @( posedge clk_i )
          if( trans_valid_i && trans_ready_o )
            begin
              storage_struct.trans_type <= trans_type_i;
              storage_struct.start_addr <= trans_addr_i;
            end

        always_ff @( posedge clk_i )
          if( trans_valid_i && trans_ready_o )
            storage_burst_en <= ( burstcount != 0 );

        always_comb
          begin
            cmp_struct_o.start_addr   = storage_struct.start_addr;
            cmp_struct_o.words_count  = burstcount;
            cmp_struct_o.data_mode    = data_mode;
            if( data_mode == RND_DATA )
              cmp_struct_o.data_ptrn  = rnd_data;
            else
              cmp_struct_o.data_ptrn  = data_ptrn;
          end

        always_ff @( posedge clk_i )
          if( start_stb )
            burst_cnt <= burstcount;
          else
            if( wr_unit_stb )
              burst_cnt <= burst_cnt - 1'b1;

        always_ff @( posedge clk_i )
          if( start_stb )
            burstcount_o <= burstcount + 1'b1;

        always_ff @( posedge clk_i )
          if( start_stb )
            address_o <= storage_struct.start_addr;

        assign byteenable_o   = '1;

      end
endgenerate

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    write_o <= 1'b0;
  else
    if( start_stb )
      if( !storage_struct.trans_type )
        write_o <= 1'b1;
      else
        write_o <= 1'b0;
    else
      if( last_transaction_stb )
        write_o <= 1'b0;

always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    read_o <= 1'b0;
  else
    if( start_stb )
      if( storage_struct.trans_type )
        read_o <= 1'b1;
      else
        read_o <= 1'b0;   
    else
      if( !waitrequest_i )
        read_o <= 1'b0;

always_ff @( posedge clk_i )
  if( writedata_en ) 
    if( data_mode == RND_DATA )
      writedata_o <= { DATA_B_W{ rnd_data  } };
    else
      writedata_o <= { DATA_B_W{ data_ptrn } };
    
always_ff @( posedge clk_i, posedge rst_i )
  if( rst_i )
    rnd_data <= '1;
  else
    if( writedata_en && ( data_mode == RND_DATA ) )
      rnd_data <= { rnd_data[6 : 0], data_gen_bit };

always_comb
  if( test_mode == WRITE_AND_CHECK )
    cmp_en_o = ( start_stb && ( !storage_struct.trans_type ) );
  else
    cmp_en_o = 1'b0;

assign data_ptrn            = test_param_i[CSR_SET_DATA  ][7 : 0              ];
assign burstcount           = test_param_i[CSR_TEST_PARAM][AMM_BURST_W - 2 : 0];

assign data_mode            = data_mode_t'( test_param_i[CSR_TEST_PARAM][12]      );
assign test_mode            = test_mode_t'( test_param_i[CSR_TEST_PARAM][15 : 14] );

assign data_gen_bit         = ( rnd_data[7] ^ rnd_data[5] ^ rnd_data[4] ^ rnd_data[3] );

assign trans_busy_o         = ( in_process || storage_valid );

assign trans_ready_o        = ( start_stb || !in_process );

assign writedata_en         = ( start_stb     && ( !storage_struct.trans_type ) ) ||
                              ( wr_unit_stb   && ( !last_transaction          ) );

assign wr_unit_stb          = ( !waitrequest_i  ) && ( write_o              );
assign last_transaction_stb = ( !waitrequest_i  ) && ( last_transaction     );
assign start_allowed        = ( !in_process     ) || ( last_transaction_stb );

assign start_stb            = ( start_allowed ) ? ( storage_valid ):
                                                  ( 1'b0          );

endmodule : transmitter_block
