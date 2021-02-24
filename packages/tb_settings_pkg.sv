package tb_settings_pkg;

parameter int CLK_SYS_T = 10_000;
parameter int CLK_MEM_T = 8_000;

parameter int RND_WAITREQ   = 0;
parameter int RND_RVALID    = 0;

typedef bit [3 : 1] [31 : 0] test_param_t;

typedef bit [14 : 5][31 : 0] test_result_t;

endpackage : tb_settings_pkg
