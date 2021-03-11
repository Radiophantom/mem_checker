import tb_settings_pkg::*;

class scoreboard;

int test_amount = 0;

typedef class random_scenario;
typedef class statistics;

random_scenario received_scen;
random_scenario reference_scen;
statistics      received_stat;
statistics      reference_stat;

mailbox driv2scb_test_mbx;
mailbox driv2scb_stat_mbx;
mailbox mem2scb_mbx;
mailbox mon2scb_mbx;

function new(
  mailbox driv2scb_test_mbx,
  mailbox driv2scb_stat_mbx,
  mailbox mem2scb_mbx,
  mailbox mon2scb_mbx
);
  this.driv2scb_test_mbx  = driv2scb_test_mbx;
  this.driv2scb_stat_mbx  = driv2scb_stat_mbx;
  this.mem2scb_mbx        = mem2scb_mbx;
  this.mon2scb_mbx        = mon2scb_mbx;
endfunction

task automatic run();
  fork
    begin
      while( test_amount )
        begin
          driv2scb_test_mbx.get( received_scen  );
          mem2scb_mbx.get      ( reference_scen );
          driv2scb_stat_mbx.get( received_stat  );
          mon2scb_mbx.get      ( reference_stat );

          if( reference_scen.test_result_registers[CSR_TEST_RESULT] == received_scen.test_result_registers[CSR_TEST_RESULT] )
            begin
              if( reference_scen.test_result_registers[CSR_TEST_RESULT] == 1 )
                begin
                  if( received_scen.test_result_registers[CSR_ERR_ADDR] != reference_scen.test_result_registers[CSR_ERR_ADDR] )
                    begin
                      $display( "Expected error address : %0d", reference_scen.test_result_registers[CSR_ERR_ADDR] );
                      $display( "Observed error address : %0d", received_scen.test_result_registers [CSR_ERR_ADDR] );
                    end
                  if( received_scen.test_result_registers[CSR_ERR_DATA] != reference_scen.test_result_registers[CSR_ERR_DATA] )
                    begin
                      $display( "Expected data error address :/n /t correct data =  %h; corrupted data =  %h", reference_scen.test_result_registers[CSR_ERR_ADDR][15 : 8], reference_scen.test_result_registers[CSR_ERR_ADDR][7 : 0] );
                      $display( "Observed data error address :/n /t correct data =  %h; corrupted data =  %h", received_scen.test_result_registers [CSR_ERR_ADDR][15 : 8], received_scen.test_result_registers [CSR_ERR_ADDR][7 : 0] );
                    end
                  $stop();
                end
            end
          else
            begin
              $display( "Invalid test behavior" );
              if( reference_scen.test_result_registers[CSR_TEST_RESULT] == 0 )
                begin
                  $display( "Expected : no error found" );
                  $display( "Observed : error found"    );
                end
              else
                begin
                  $display( "Expected : error found"    );
                  $display( "Observed : no error found" );
                end
              $stop();
            end

          foreach( reference_stat.stat_registers[i] )
            if( reference_stat.stat_registers[i] != received_stat.stat_registers[i] )
              begin
                $display( "Expected %0d register value : %0d", i, reference_stat.stat_registers[i] );
                $display( "Observed %0d register value : %0d", i, received_stat.stat_registers [i] );
                $stop();
              end

          test_amount--;
        end

        $display( "Test successfully passed, congratulations ladies and gentlements" );
        $stop();
    end
  join_none
endtask : run

endclass : scoreboard