import rtl_settings_pkg::*;

program test(
  amm_if.csr #(
    .ADDR_W ( 4 ),
    .DATA_W ( 32 )
  ) amm_if_csr,
  amm_if.slave #(
    .ADDR_W ( AMM_ADDR_W ),
    .DATA_W ( AMM_DATA_W ),
    .BURST_W ( AMM_BURST_W )
  ) amm_if_mem
);

environment env;

initial
  begin
    env = new( amm_if_csr, amm_if_mem );

    env.run();
  end

endprogram : test
