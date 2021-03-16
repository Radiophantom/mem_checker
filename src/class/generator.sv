import tb_settings_pkg::*;

class generator;

typedef class random_scenario;

random_scenario rnd_scen_driv_obj;
random_scenario rnd_scen_mem_obj;

mailbox   gen2driv_mbx;
mailbox   gen2mem_mbx;

covergroup CovMode;
	test_mode : coverpoint rnd_scen_driv_obj.test_mode {
    illegal_bins low = { 0 };
    option.weight = 0;
  }
	addr_mode : coverpoint rnd_scen_driv_obj.addr_mode {
    illegal_bins hi = { [5 : 7] };
    option.weight = 0;
  }
	data_mode : coverpoint rnd_scen_driv_obj.data_mode {
    option.weight = 0;
  }
  
  cross test_mode, addr_mode, data_mode;
  
  coverpoint rnd_scen_driv_obj.trans_amount;
  coverpoint rnd_scen_driv_obj.burstcount;
endgroup : CovMode

function new(
  mailbox gen2driv_mbx,
  mailbox gen2mem_mbx
);
	CovMode = new();
  this.gen2driv_mbx = gen2driv_mbx;
  this.gen2mem_mbx  = gen2mem_mbx;
endfunction

function automatic void send_test();
  void'( rnd_scen_driv_obj.randomize() );
  rnd_scen_mem_obj  = new rnd_scen_driv_obj;
  gen2driv_mbx.put( rnd_scen_driv_obj );
  gen2mem_mbx.put ( rnd_scen_mem_obj  );
  CovMode.sample();
endfunction : send_test

task automatic run();
  fork
    begin
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability();
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();  
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(0, 0, 100);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(0, 100, 0);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(100, 0, 0);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(50, 25, 25);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(25, 50, 25);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
      repeat( 500 )
        begin
          rnd_scen_driv_obj = new();
          rnd_scen_driv_obj.set_test_mode_probability(25, 25, 50);
          rnd_scen_driv_obj.set_addr_mode_probability();
          rnd_scen_driv_obj.set_err_probability();
          send_test();
        end
    end
  join_none
endtask : run

endclass : generator