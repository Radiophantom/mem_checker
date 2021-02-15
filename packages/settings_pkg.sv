package settings_pkg;

parameter int MEM_ADDR_W  = 31;
parameter int MEM_DATA_W  = 16;
parameter int AMM_ADDR_W  = 28;
parameter int AMM_DATA_W  = 128;
parameter int WORD_KOEF   = $clog2( AMM_DATA_W / MEM_DATA_W );

parameter string  ADDR_TYPE  = "BYTE"; // BYTE or WORD

//if( ADDR_TYPE == "BYTE" )
  parameter int ADDR_W  = MEM_ADDR_W + $clog2( MEM_DATA_W / 8 );
//else if( ADDR_TYPE == "WORD" )
  //parameter int ADDR_W  = MEM_ADDR_W - WORD_KOEF;

parameter int AMM_BURST_W = 11;

parameter int DATA_B_W = AMM_DATA_W/8;
parameter int ADDR_B_W = $clog2( DATA_B_W );


parameter int RND_WAITREQ   = 0;
parameter int RND_RVALID    = 0;

parameter int CLK_SYS_T = 10_000;
parameter int CLK_MEM_T = 8_000;

typedef enum logic {
  FIX_DATA,
  RND_DATA
} data_mode_type;

typedef enum logic [1:0] {
  READ_ONLY       = 2'b01,
  WRITE_ONLY      = 2'b10,
  WRITE_AND_CHECK = 2'b11
} test_mode_type;

typedef enum logic [2:0] {
  FIX_ADDR  = 3'b000,
  RND_ADDR  = 3'b001,
  RUN_0     = 3'b010,
  RUN_1     = 3'b011,
  INC_ADDR  = 3'b100
} addr_mode_type;

typedef struct packed{
  logic [ADDR_W - 1 : 0]      word_addr;
  logic [AMM_BURST_W - 1 : 0] burst_word_count;
  logic [DATA_B_W - 1 : 0]    start_mask;
  logic [DATA_B_W - 1 : 0]    end_mask;
  logic [7 : 0]               data_ptrn;
  logic                       data_ptrn_type;
} pkt_struct_t;

typedef struct packed{
  logic [ADDR_W - 1 : 0] word_addr;
  logic [AMM_BURST_W - 2 : 0] high_burst_bits;
  logic [ADDR_B_W - 1 : 0]    low_burst_bits;
  logic [ADDR_B_W - 1 : 0]    start_offset;
  logic [ADDR_B_W - 1 : 0]    end_offset;
} trans_struct_t;

typedef struct{
  bit           error;
  bit [11 : 0]  error_num;
} err_struct_t;

typedef struct{
  bit [31 : 0] csr_1_reg;
  bit [31 : 0] csr_2_reg;
  bit [31 : 0] csr_3_reg;
} test_struct_t;

typedef struct packed{
  bit [31 : 0] result_reg;
  bit [31 : 0] err_addr_reg;
  bit [31 : 0] err_data_reg;
  bit [31 : 0] wr_ticks_reg;
  bit [31 : 0] wr_units_reg;
  bit [31 : 0] rd_ticks_reg;
  bit [31 : 0] rd_words_reg;
  bit [31 : 0] min_max_reg;
  bit [31 : 0] sum_reg;
  bit [31 : 0] rd_req_reg;
} res_struct_t;

endpackage
