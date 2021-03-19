//*******************************************************************************//
// Class allows to set distribution probabilities and generate test scenarios.   //
// Duplicates generated scenarios and sends it to 'driver' and 'memory' classes. //
//*******************************************************************************//

class generator;

//*****************************************
// Class variables and objects declaration
//*****************************************

typedef class random_scenario;

random_scenario rnd_scen_driv_obj;
random_scenario rnd_scen_mem_obj;

mailbox   gen2driv_mbx;
mailbox   gen2mem_mbx;

int test_amount = 0;

//*****************************************
// Covergroup declaration
//*****************************************

covergroup CovMode;
	test_mode : coverpoint rnd_scen_driv_obj.test_mode {
    illegal_bins low = { 0 };
  }
	addr_mode : coverpoint rnd_scen_driv_obj.addr_mode {
    illegal_bins hi = { [5 : 7] };
  }
	data_mode : coverpoint rnd_scen_driv_obj.data_mode;
  
  cross test_mode, addr_mode, data_mode;
  
  coverpoint rnd_scen_driv_obj.trans_amount;
  coverpoint rnd_scen_driv_obj.burstcount;
endgroup : CovMode

//*****************************************
// Functions
//*****************************************

function new(
  mailbox gen2driv_mbx,
  mailbox gen2mem_mbx
);
	CovMode = new();
  this.gen2driv_mbx = gen2driv_mbx;
  this.gen2mem_mbx  = gen2mem_mbx;
endfunction : new

//*****************************************
// Tasks
//*****************************************

task automatic generate_test();
  void'( rnd_scen_driv_obj.randomize() );
  // Sample coverage statistics of generated test
  CovMode.sample();
  // Copy scenario for 'memory' class
  rnd_scen_mem_obj  = new rnd_scen_driv_obj;
  // Send scenario to 'driver' and 'memory' classes
  gen2driv_mbx.put( rnd_scen_driv_obj );
  gen2mem_mbx.put ( rnd_scen_mem_obj  );
  // Count generated test amount for 'scoreboard' class
  test_amount++;
endtask : generate_test

task automatic run();
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability();
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();  
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(0, 0, 100);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(0, 100, 0);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(100, 0, 0);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(50, 25, 25);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(25, 50, 25);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
  repeat( 500 )
    begin
      rnd_scen_driv_obj = new();
      rnd_scen_driv_obj.set_test_mode_probability(25, 25, 50);
      rnd_scen_driv_obj.set_addr_mode_probability();
      rnd_scen_driv_obj.set_err_probability();
      generate_test();
    end
endtask : run

endclass : generator