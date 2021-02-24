import tb_settings_pkg::*;

class scoreboard();

random_scenario   received_scen;
random_scenario   reference_scen;

mailbox driv2scb;
mailbox mem2scb;

function new(
  mailbox driv2scb,
  mailbox mem2scb
);
  this.driv2scb = driv2scb;
  this.mem2scb  = mem2scb;
endfunction

function automatic void run();
  fork
    forever
      begin
        driv2scb.get( received_scen   );
        mem2scb.get ( reference_scen  );
        if( reference_scen.error_enable == received_scen.result_registers[5] )
          if( received_scen.err_addr == reference_scen.err_addr )
            $display( "Correct test behavior" );
          else
            begin
              $display( "Invalid test behavior" );
              $stop();
            end
        else
          begin
            $display( "Invalid test behavior" );
            $display( "Expected : %0d", reference_scen.err_addr );
            $display( "Observed : %0d", received_scen.err_addr );
          end
      end
  join_none
endfunction : run

endclass : scoreboard


