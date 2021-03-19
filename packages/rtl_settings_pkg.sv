package rtl_settings_pkg;

parameter int     MEM_ADDR_W    = 26; // must be fit to address space not greater than 4Gb (consider MEM_DATA_W parameter)
parameter int     MEM_DATA_W    = 512;
parameter int     MEM_DATA_B_W  = ( MEM_DATA_W / 8 );

parameter int     AMM_ADDR_W    = 32;
parameter int     AMM_DATA_W    = 512; // max value 512 - 200 MHz; max value 1024 - 170 MHz;
parameter int     AMM_BURST_W   = 6;  // max value 11

parameter int     DATA_B_W      = ( AMM_DATA_W / 8 );
parameter int     ADDR_B_W      = $clog2( DATA_B_W );

parameter string  ADDR_TYPE     = "BYTE"; // "BYTE" or "WORD"

parameter int     ADDR_W        = ( ADDR_TYPE == "BYTE" ) ? ( MEM_ADDR_W + $clog2( MEM_DATA_W / 8 )          ):
                                                            ( MEM_ADDR_W - $clog2( AMM_DATA_W / MEM_DATA_W ) );

parameter int     CMP_ADDR_W    = ( ADDR_TYPE == "BYTE" ) ? ( ADDR_W - ADDR_B_W ):
                                                            ( ADDR_W            );


parameter int CSR_TEST_START  = 0;
parameter int CSR_TEST_PARAM  = 1;
parameter int CSR_SET_ADDR    = 2;
parameter int CSR_SET_DATA    = 3;
parameter int CSR_TEST_FINISH = 4;
parameter int CSR_TEST_RESULT = 5;
parameter int CSR_ERR_ADDR    = 6;
parameter int CSR_ERR_DATA    = 7;
parameter int CSR_WR_TICKS    = 8;
parameter int CSR_WR_UNITS    = 9;
parameter int CSR_RD_TICKS    = 10;
parameter int CSR_RD_WORDS    = 11;
parameter int CSR_MIN_DEL     = 12;
parameter int CSR_MAX_DEL     = 13;
parameter int CSR_SUM_DEL     = 14;
parameter int CSR_RD_REQ      = 15;

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
  logic         [CMP_ADDR_W - 1  : 0]   start_addr;
  logic                                 trans_type;
  logic         [ADDR_B_W - 1    : 0]   start_off;
  logic         [ADDR_B_W - 1    : 0]   end_off;
  logic         [AMM_BURST_W - 2 : 0]   words_count;
  data_mode_t                           data_mode;
  logic         [7 : 0]                 data_ptrn;
} cmp_struct_t;

function automatic logic [DATA_B_W - 1 : 0] byteenable_ptrn(
  logic                     start_enable,
  logic [ADDR_B_W - 1 : 0]  start_offset,
  logic                     finish_enable,
  logic [ADDR_B_W - 1 : 0]  finish_offset
);
  for( int i = 0; i < DATA_B_W; i++ )
    case( { start_enable, finish_enable } )
      0 : byteenable_ptrn[i] = 1'b1;
      1 : byteenable_ptrn[i] = ( i <= finish_offset );
      2 : byteenable_ptrn[i] = ( i >= start_offset  );
      3 : byteenable_ptrn[i] = ( i >= start_offset  ) && ( i <= finish_offset );
      default : byteenable_ptrn[i] = 1'bX;
    endcase
endfunction : byteenable_ptrn

function automatic logic [DATA_B_W - 1 : 0] check_vector(
  logic [DATA_B_W - 1       : 0]          check_ptrn,
  logic [7                  : 0]          data_ptrn,
  logic [AMM_DATA_W / 8 - 1 : 0][7 : 0]   readdata
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_ptrn[i] )
      check_vector[i] = ( data_ptrn != readdata[i] );
    else
      check_vector[i] = 1'b0;
endfunction : check_vector

function automatic logic [ADDR_B_W - 1 : 0] err_byte_find(
  logic [DATA_B_W - 1 : 0] check_vector
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( check_vector[i] )
      return( i );
  return( 0 );
endfunction : err_byte_find

// function automatic logic [ADDR_B_W : 0] bytes_count(
//   logic [DATA_B_W - 1 : 0] byteenable
// );
//   bytes_count = 0;
//   for( int i = 0; i < DATA_B_W; i++ )
//     if( byteenable[i] )
//       bytes_count++;
// endfunction : bytes_count

function automatic int bytes_count(
  logic [127 : 0] byteenable
);
  bytes_count = 0;
  for( int i = 0; i < 127; i++ )
    if( byteenable[i] )
      bytes_count++;
endfunction : bytes_count

endpackage : rtl_settings_pkg