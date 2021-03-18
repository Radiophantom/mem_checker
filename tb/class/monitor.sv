//****************************************************//
// Class monitors memory controller AMM interface and //
// gather reference transaction statistics.           //
//****************************************************//

import rtl_settings_pkg::*;

class monitor;

//****************************************************
// Class variables, objects and interface declaration
//****************************************************

typedef class statistics;

statistics    stat_obj;

mailbox       mon2scb_mbx;

event         test_finished;

int next_trans_id = 0;
int cur_trans_id  = 0;

virtual amm_if #(
  .ADDR_W   ( AMM_ADDR_W  ),
  .DATA_W   ( AMM_DATA_W  ),
  .BURST_W  ( AMM_BURST_W )
) amm_if_v;

//***********************************************
// Class allocating and interface initialization
//***********************************************

function new(
  virtual amm_if #(
    .ADDR_W   ( AMM_ADDR_W  ),
    .DATA_W   ( AMM_DATA_W  ),
    .BURST_W  ( AMM_BURST_W )
  ) amm_if_v,
  mailbox mon2scb_mbx,
  event   test_finished
);
  this.amm_if_v       = amm_if_v;
  this.mon2scb_mbx    = mon2scb_mbx;
  this.test_finished  = test_finished;
  init_interface();
endfunction

local function automatic void init_interface();
  amm_if_v.read           = 1'b0;
  amm_if_v.write          = 1'b0;
  amm_if_v.readdatavalid  = 1'b0;
  amm_if_v.waitrequest    = 1'b0;
  amm_if_v.address        = '0;
  amm_if_v.writedata      = '0;
  amm_if_v.burstcount     = '0;
  amm_if_v.readdata       = '0;
//amm_if_v.byteenable     = '0;
endfunction : init_interface

//******************************
// Write transaction statistics
//******************************

local task automatic wr_stat_gather();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.write )
        begin
          // ticks count
          stat_obj.wr_ticks_count();
          // units count
          if( !amm_if_v.waitrequest )
            if( ADDR_TYPE == "BYTE" )
              stat_obj.wr_units_count( bytes_count( amm_if_v.byteenable ) );
            else
              stat_obj.wr_units_count( 1 );
        end
    end
endtask : wr_stat_gather

//******************************
// Read transaction statistics
//******************************

local task automatic rd_stat_gather();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.readdatavalid )
        stat_obj.rd_words_count();
      if( next_trans_id != cur_trans_id )  
        stat_obj.rd_ticks_count();
    end
endtask : rd_stat_gather

local task automatic rd_delay_stat_gather();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.read )
        begin
          // delay counter launch
          fork
            delay_count( next_trans_id );
          join_none
          stat_obj.rd_req_count();
          // wait for read request accepting
          while( amm_if_v.waitrequest )
            @( posedge amm_if_v.clk );
        end 
    end
endtask : rd_delay_stat_gather

//******************************
// Delay statistics
//******************************

local task automatic delay_count( int trans_id );
  int words_amount  = amm_if_v.burstcount;
  int delay_cnt     = 0;

  // increment after all tasks done
  #0;
  next_trans_id++;

  fork
    while( 1 )
      begin
        @( posedge amm_if_v.clk );
        delay_cnt++;
        if( amm_if_v.readdatavalid && ( trans_id == cur_trans_id ) )
          break;
      end
  join_none

  while( words_amount )
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.readdatavalid && ( trans_id == cur_trans_id ) )
        words_amount--;
    end

  // increment after all tasks done
  #0;
  cur_trans_id++;

  stat_obj.rd_delay_count( delay_cnt );
endtask : delay_count

//******************************
// Run task
//******************************

task automatic run();
  fork
    wr_stat_gather();
    rd_stat_gather();
    rd_delay_stat_gather();
  join_none

  fork
    forever
      begin
        stat_obj = new();
        @( test_finished );
        mon2scb_mbx.put( stat_obj );
      end
  join_none
endtask : run

endclass : monitor