package rtl_settings_pkg;

parameter int     MEM_ADDR_W  = 29;
parameter int     MEM_DATA_W  = 64;
parameter int     AMM_ADDR_W  = 32;
parameter int     AMM_DATA_W  = 128;
parameter int     AMM_BURST_W = 11;

parameter int     DATA_B_W    = ( AMM_DATA_W / 8 );
parameter int     ADDR_B_W    = $clog2( DATA_B_W );

parameter string  ADDR_TYPE   = "BYTE"; // "BYTE" or "WORD"

parameter int     ADDR_W      = ( ADDR_TYPE == "BYTE" ) ? ( MEM_ADDR_W + $clog2( MEM_DATA_W / 8 )          ):
                                                          ( MEM_ADDR_W - $clog2( AMM_DATA_W / MEM_DATA_W ) );

typedef enum logic [1:0] {
  READ_ONLY       = 2'b01,
  WRITE_ONLY      = 2'b10,
  WRITE_AND_CHECK = 2'b11
} test_mode_t;

typedef enum logic [2:0] {
  FIX_ADDR    = 3'b000,
  RND_ADDR    = 3'b001,
  RUN_0_ADDR  = 3'b010,
  RUN_1_ADDR  = 3'b011,
  INC_ADDR    = 3'b100
} addr_mode_t;

typedef enum logic {
  FIX_DATA = 1'b0,
  RND_DATA = 1'b1
} data_mode_t;

typedef struct packed{
  logic [ADDR_W - 1 : 0]      start_addr;
  logic                       trans_type;
  logic [ADDR_B_W - 1 : 0]    start_off;
  logic [ADDR_B_W - 1 : 0]    end_off;
  logic [AMM_BURST_W - 2 : 0] words_count;
  data_mode_t                 data_mode;
  logic [7 : 0]               data_ptrn;
} cmp_struct_t;

function automatic logic [DATA_B_W - 1 : 0] byteenable_ptrn(
  logic                     start_enable,
  logic                     end_enable,
  logic [ADDR_B_W - 1 : 0]  start_offset,
  logic [ADDR_B_W - 1 : 0]  end_offset
);
  for( int i = 0; i < DATA_B_W; i++ )
    case( { start_enable, end_enable } )
      0 : byteenable_ptrn[i] = 1'b1;
      1 : byteenable_ptrn[i] = ( i <= end_offset   );
      2 : byteenable_ptrn[i] = ( i >= start_offset );
      3 : byteenable_ptrn[i] = ( i >= start_offset ) && ( i <= end_offset );
      default : byteenable_ptrn[i] = 1'bX;
    endcase
endfunction : byteenable_ptrn

function automatic logic [DATA_B_W - 1 : 0] check_vector(
  logic [DATA_B_W - 1 : 0]    check_ptrn,
  logic [7 : 0]               data_ptrn,
  logic [AMM_DATA_W - 1 : 0]  readdata
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_ptrn[i] )
      check_vector[i] = ( data_ptrn != readdata[7 + i*8 -: 8] );
    else
      check_vector[i] = 1'b0;
endfunction : check_vector

function automatic logic [ADDR_B_W - 1 : 0] err_byte(
  ref logic [DATA_B_W - 1 : 0] check_vector
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_vector[i] )
      return( i );
  return( 0 );
endfunction : err_byte

endpackage : rtl_settings_pkg
