package tb_settings_pkg;

parameter int CLK_SYS_T = 10_000;
parameter int CLK_MEM_T = 8_000;

parameter int RND_WAITREQ   = 0;
parameter int RND_RVALID    = 0;

typedef bit [CSR_SET_DATA : CSR_TEST_PARAM] [31 : 0] test_param_t;

typedef bit [CSR_RD_REQ : CSR_TEST_RESULT][31 : 0] test_result_t;

endpackage : tb_settings_pkg
