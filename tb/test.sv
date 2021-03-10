`include "./src/class/environment.sv"

import rtl_settings_pkg::*;

module test(
  amm_if.csr amm_if_csr,
  amm_if.mem amm_if_mem
);

//typedef class environment;

environment env;

initial
  begin
    env = new( amm_if_csr, amm_if_mem );
    repeat( 10 )
      @( posedge amm_if_csr.clk );
    env.run();
  end

endmodule : test