import rtl_settings_pkg.sv::*;
import tb_settings_pkg.sv::*;

class monitor();

statistics stat_obj;

mailbox mon2scb_mbx;

event   test_finished;

bit [7 : 0] wr_ticks;
bit [7 : 0] wr_units;
bit [7 : 0] rd_ticks;
bit [7 : 0] rd_words;
bit [7 : 0] min_delay;
bit [7 : 0] max_delay;
bit [7 : 0] sum_delay;
bit [7 : 0] rd_req_amount;

int next_trans_id     = 0;
int cur_trans_id      = 0;
int words_amount_left = 0;

virtual amm_if #(
  .ADDR_W   ( ADDR_W  ),
  .DATA_W   ( DATA_W  ),
  .BURST_W  ( BURST_W )
) amm_if_v;

function new(
  virtual amm_if #(
    .ADDR_W   ( ADDR_W  ),
    .DATA_W   ( DATA_W  ),
    .BURST_W  ( BURST_W )
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
  amm_if_v.byteenable     = '0;
  amm_if_v.burstcount     = '0;
  amm_if_v.readdata       = '0;
endfunction : init_interface

local function automatic void reset_stat();
  wr_ticks       = 0;
  wr_units       = 0;
  rd_ticks       = 0;
  rd_words       = 0;
  min_delay      = 0;
  max_delay      = 0;
  sum_delay      = 0;
  rd_req_amount  = 0;
endfunction : reset_variables

local task automatic wr_ticks_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.write )
        wr_ticks++;
    end
endtask : rd_words_count

local function automatic int bytes_count();
  foreach( amm_if_v.byteenable[i] )
    if( amm_if_v.byteenable[i] )
      bytes_count++;
endfunction : bytes_count

local task automatic wr_units_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.write && ( !amm_if_v.waitrequest ) )
        if( ADDR_TYPE == "BYTE" )
          wr_units += bytes_count();
        else
          wr_units += 1;
    end
endtask : wr_units_count

local task automatic rd_words_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.readdatavalid )
        rd_words++;
    end
endtask : rd_words_count

local task automatic rd_req_count();
  fork
    forever
      begin
        @( posedge amm_if_v.clk );
        if( amm_if_v.read )
          begin
            delay_count( next_trans_id );
            words_amount_left += amm_if_v.burstcount;
            next_trans_id++;
            rd_req_amount++;
            wait( !amm_if_v.waitrequest );
          end 
      end
    forever
      begin
        @( posedge amm_if_v.clk );
        if( amm_if_v.readdatavalid )
          words_amount_left--;
      end
  join_none
endtask : rd_req_count

local task automatic delay_count( int trans_id );
  int delay_cnt     = 0;
  int words_amount  = amm_if_v.burstcount;

  fork : delay_process
    forever
      begin
        @( posedge amm_if_v.clk );
        delay_cnt++;
      end
    forever
      begin
        @( posedge amm_if_v.clk );
        
      while( 
      wait( trans_id == cur_trans_id );
      do
      while( amm_if_v.readdatavalid );
  join_any

  disable delay_process;

  if( delay_cnt < min_delay )
    min_delay = delay_cnt;
  if( delay_cnt > max_delay )
    max_delay = delay_cnt;
  sum_delay += delay_cnt;

  fork
    words_amount--;

  join_none
endtask : delay_count
  
local task automatic rd_ticks_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( words_amount_left )
        rd_ticks++;
    end
endtask : rd_ticks

task automatic run();
  fork
    rd_bytes_count();
    wr_bytes_count();
    wr_ticks_count();
    rd_req_count();
  join_none

  fork
    forever
      begin
        @( test_finished );
        stat_obj = new();
        save_stat();
        reset_stat();
        mon2scb_mbx.put( stat_obj );
      end
  join_none
endtask : run

endclass : monitor
