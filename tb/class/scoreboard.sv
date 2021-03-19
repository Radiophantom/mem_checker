//************************************************************************************//
// Class compares reference test results received from 'memory' and 'monitor' classes //
// with respective results received from 'driver' class. If invalid memory checker    //
// behavior observed, then displays error CSR's contents and stops simulation.        //
//************************************************************************************//

import rtl_settings_pkg::CSR_TEST_RESULT;
import rtl_settings_pkg::CSR_ERR_ADDR;
import rtl_settings_pkg::CSR_ERR_DATA;

class scoreboard;

//*****************************
// Class variables declaration
//*****************************

typedef class   random_scenario;
typedef class   statistics;

random_scenario rcv_scen;
random_scenario ref_scen;
statistics      rcv_stat;
statistics      ref_stat;

mailbox         driv2scb_test_mbx;
mailbox         driv2scb_stat_mbx;
mailbox         mem2scb_mbx;
mailbox         mon2scb_mbx;

int test_amount = 0;

//*****************************
// Functions
//*****************************

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
endfunction : new

//*****************************
// Tasks
//*****************************

task automatic run();
  fork
    begin
      repeat( test_amount )
        begin
          driv2scb_test_mbx.get( rcv_scen  );
          driv2scb_stat_mbx.get( rcv_stat  );
          mem2scb_mbx.get      ( ref_scen );
          mon2scb_mbx.get      ( ref_stat );
          // check error detection behavior
          if( ref_scen.test_result_registers[CSR_TEST_RESULT] == rcv_scen.test_result_registers[CSR_TEST_RESULT] )
            begin
              if( ref_scen.test_result_registers[CSR_TEST_RESULT] == 1 )
                begin
                  if( ref_scen.test_result_registers[CSR_ERR_ADDR] != rcv_scen.test_result_registers[CSR_ERR_ADDR] )
                    begin
                      $display( "Invalid test behavior" );
                      $display( "Expected error address : %h", ref_scen.test_result_registers[CSR_ERR_ADDR] );
                      $display( "Observed error address : %h", rcv_scen.test_result_registers[CSR_ERR_ADDR] );
                      $stop();
                    end
                  if( ref_scen.test_result_registers[CSR_ERR_DATA] != rcv_scen.test_result_registers[CSR_ERR_DATA] )
                    begin
                      $display( "Invalid test behavior" );
                      $display( "Expected data error address : correct data =  %h; corrupted data =  %h", ref_scen.test_result_registers[CSR_ERR_DATA][15 : 8], ref_scen.test_result_registers[CSR_ERR_DATA][7 : 0] );
                      $display( "Observed data error address : correct data =  %h; corrupted data =  %h", rcv_scen.test_result_registers[CSR_ERR_DATA][15 : 8], rcv_scen.test_result_registers[CSR_ERR_DATA][7 : 0] );
                      $stop();
                    end
                end
            end
          else
            begin
              $display( "Invalid test behavior" );
              if( ref_scen.test_result_registers[CSR_TEST_RESULT] == 0 )
                begin
                  $display( "Expected behavior : no error found" );
                  $display( "Observed behavior : error found"    );
                end
              else
                begin
                  $display( "Expected behavior : error found"    );
                  $display( "Observed behavior : no error found" );
                end
              $stop();
            end
          // check statistics registers content
          foreach( ref_stat.stat_registers[i] )
            if( ref_stat.stat_registers[i] != rcv_stat.stat_registers[i] )
              begin
                $display( "Expected %d register value : %h", i, ref_stat.stat_registers[i] );
                $display( "Observed %d register value : %h", i, rcv_stat.stat_registers [i] );
                $stop();
              end
        end
        $display( "Test successfully passed, congratulations ladies and gentlements" );
        $stop();
    end
  join_none
endtask : run

endclass : scoreboard