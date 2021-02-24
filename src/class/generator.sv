`include "./random_scenario.sv"

class generator;

random_scenario   rnd_scen_obj;

mailbox   gen2driv_mbx;
mailbox   gen2mem_mbx;

function new(
  mailbox gen2driv_mbx,
  mailbox gen2mem_mbx
);
  this.gen2driv_mbx = gen2driv_mbx;
  this.gen2mem_mbx  = gen2mem_mbx;
endfunction

task automatic void run();
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability();
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(0, 0, 100);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(0, 100, 0);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(100, 0, 0);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(50, 25, 25);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(25, 50, 25);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
  repeat( 500 )
    begin
      rnd_scen_obj = new();
      rnd_scen_obj.set_test_mode_probability(25, 25, 50);
      rnd_scen_obj.set_addr_mode_probability();
      rnd_scen_obj.set_err_probability();
      rnd_scen_obj.randomize();
      gen2mem_mbx.put ( rnd_scen_obj );
      gen2driv_mbx.put( rnd_scen_obj );
    end
endtask : run

endclass : generator
