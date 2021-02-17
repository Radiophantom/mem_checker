package tb_settings_pkg;

parameter int CLK_SYS_T = 10_000;
parameter int CLK_MEM_T = 8_000;

parameter int RND_WAITREQ   = 0;
parameter int RND_RVALID    = 0;

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

endpackage : tb_settings_pkg
