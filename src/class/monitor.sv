import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class monitor;

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

typedef class statistics;

statistics stat_obj;

mailbox mon2scb_mbx;

event   test_finished;

virtual amm_if #(
  .ADDR_W   ( AMM_ADDR_W  ),
  .DATA_W   ( AMM_DATA_W  ),
  .BURST_W  ( AMM_BURST_W )
) amm_if_v;

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
  cur_trans_id   = 0;
  next_trans_id  = 0;
endfunction : reset_stat

local task automatic wr_ticks_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.write )
        wr_ticks++;
    end
endtask : wr_ticks_count

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
        begin
          rd_words++;
          words_amount_left--;
        end
    end
endtask : rd_words_count

local task automatic rd_req_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( amm_if_v.read )
        begin
          fork
            delay_count( next_trans_id );
          join_none
          words_amount_left += amm_if_v.burstcount;
          next_trans_id++;
          rd_req_amount++;
          wait( !amm_if_v.waitrequest );
        end 
    end
endtask : rd_req_count

local task automatic delay_count( int trans_id );
  int words_amount  = amm_if_v.burstcount;
  int delay_cnt     = 0;
  int count_enable  = 1;

  fork
    while( count_enable )
      begin
        @( posedge amm_if_v.clk );
        delay_cnt++;
      end
  join_none

  while( words_amount )
    begin
      @( posedge amm_if_v.clk );
      if( trans_id == cur_trans_id )
        if( amm_if_v.readdatavalid )
          begin
            words_amount--;
            count_enable = 0;
          end
    end

  cur_trans_id++;

  if( delay_cnt < min_delay )
    min_delay = delay_cnt;
  if( delay_cnt > max_delay )
    max_delay = delay_cnt;
  sum_delay += delay_cnt;
endtask : delay_count
  
local task automatic rd_ticks_count();
  forever
    begin
      @( posedge amm_if_v.clk );
      if( words_amount_left )
        rd_ticks++;
    end
endtask : rd_ticks_count

local function automatic void save_stat();
  stat_obj.stat_registers[CSR_WR_TICKS] = wr_ticks;
  stat_obj.stat_registers[CSR_WR_UNITS] = wr_units;
  stat_obj.stat_registers[CSR_RD_TICKS] = rd_ticks;
  stat_obj.stat_registers[CSR_RD_WORDS] = rd_words;
  stat_obj.stat_registers[CSR_MIN_DEL ] = min_delay;
  stat_obj.stat_registers[CSR_MAX_DEL ] = max_delay;
  stat_obj.stat_registers[CSR_SUM_DEL ] = sum_delay;
  stat_obj.stat_registers[CSR_RD_REQ  ] = rd_req_amount;
endfunction : save_stat

task automatic run();
  fork
    wr_ticks_count();
    wr_units_count();
    rd_ticks_count();
    rd_words_count();
    rd_req_count  ();
  join_none

  fork
    forever
      begin
        @( test_finished );
        stat_obj = new();
        save_stat ();
        reset_stat();
        mon2scb_mbx.put( stat_obj );
      end
  join_none
endtask : run

endclass : monitor