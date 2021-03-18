//*************
// Class emulates behavior of memory controller. Insert error, if need, and send error address and corrupted data to 'scoreboard' class.
//***************

import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class amm_memory;

//****************************************************
// Class variables, objects and interface declaration
//****************************************************

typedef class random_scenario;

random_scenario rnd_scen_obj;

mailbox gen2mem_mbx;
mailbox mem2scb_mbx;

event test_started;
event test_finished;

// need to control write daemons executing order
semaphore write_in_process = new( 1 );

bit [7 : 0] memory_array    [*];
bit [7 : 0] rd_data_channel [$];
bit [7 : 0] wr_data_channel [$];

// save data stream with respective byteenable mask
typedef struct{
  bit [DATA_B_W - 1   : 0]  byteenable;
  bit [AMM_DATA_W - 1 : 0]  writedata;
} wr_data_t;

wr_data_t amm_data_channel [$];

int insert_error;
int cur_trans_num;
int err_trans_num;
int err_byte_num;

int seed = 0;

virtual amm_if #(
  .ADDR_W   ( AMM_ADDR_W  ),
  .DATA_W   ( AMM_DATA_W  ),
  .BURST_W  ( AMM_BURST_W )
) amm_if_v;

//****************************************************
// Class allocating and interface initialization
//****************************************************

function new(
  virtual amm_if #(
    .ADDR_W   ( AMM_ADDR_W  ),
    .DATA_W   ( AMM_DATA_W  ),
    .BURST_W  ( AMM_BURST_W )
  ) amm_if_v,
  mailbox gen2mem_mbx,
  mailbox mem2scb_mbx,
  event   test_started,
  event   test_finished
);
  this.amm_if_v       = amm_if_v;
  this.gen2mem_mbx    = gen2mem_mbx;
  this.mem2scb_mbx    = mem2scb_mbx;
  this.test_started   = test_started;
  this.test_finished  = test_finished;
  init_interface();
endfunction

local function automatic void init_interface();
  amm_if_v.read           = 1'b0;
  amm_if_v.write          = 1'b0;
  amm_if_v.readdatavalid  = 1'b0;
  amm_if_v.waitrequest    = 1'b0;
  amm_if_v.readdata       = '0;
  amm_if_v.address        = '0;
  amm_if_v.writedata      = '0;
  amm_if_v.burstcount     = '0;
//amm_if_v.byteenable     = '0;
endfunction : init_interface

//****************************************************
// Write transaction tasks
//****************************************************

local task automatic prep_wr_data(
  int unsigned  wr_addr,
  int           trans_amount
);
  wr_data_t wr_data;
  int       byte_num = 0;
  bit [7 : 0] wr_byte;

  write_in_process.get();
  fork : wr_mem_daemon_fork
    wr_mem( wr_addr );
  join_none
  repeat( trans_amount )
    begin
      wait( amm_data_channel.size() > 0 );
      wr_data = amm_data_channel.pop_front();
      for( int i = 0; i < DATA_B_W; i++ )
        begin
          if( wr_data.byteenable[i] )
            begin
              if( insert_error && ( cur_trans_num == err_trans_num ) && ( byte_num == err_byte_num ) )
                wr_byte = corrupt_data( wr_addr, amm_if_v.writedata[7 + i * 8 -: 8] );
              else
                wr_byte = wr_data.writedata[7 + i * 8 -: 8];
              wr_data_channel.push_back( wr_byte );
              byte_num++;
            end
        end
      wait( wr_data_channel.size() <= 3 * DATA_B_W );
    end
  wait( wr_data_channel.size() == 0 );
  disable wr_mem_daemon_fork;
  write_in_process.put();
  cur_trans_num++;
endtask : prep_wr_data

local task automatic wr_mem(
  int unsigned  wr_addr
);
  forever
    begin
      @( posedge amm_if_v.clk );
      repeat( MEM_DATA_B_W )
        if( wr_data_channel.size() )
          begin
            memory_array[wr_addr] = wr_data_channel.pop_front();
            wr_addr++;
          end
    end
endtask : wr_mem

local task automatic wr_data();
  int unsigned  wr_addr;
  int           trans_amount;
  wr_data_t     wr_data;

  if( ADDR_TYPE == "BYTE" )
    wr_addr = amm_if_v.address + start_offset( amm_if_v.byteenable );
  else
    wr_addr = amm_if_v.address * DATA_B_W;
  trans_amount  = amm_if_v.burstcount;

  fork
    prep_wr_data( wr_addr, trans_amount );
  join_none

  while( trans_amount )
    begin
      if( amm_if_v.write )
        begin
          amm_if_v.waitrequest <= 1'b1;
          wr_data.byteenable = amm_if_v.byteenable;
          wr_data.writedata  = amm_if_v.writedata;
          amm_data_channel.push_back( wr_data );
          while( amm_data_channel.size() > 1 );
            @( posedge amm_if_v.clk );
          if( RND_WAITREQ )
            begin
              while( $urandom_range( 1 ) )
                @( posedge amm_if_v.clk );
            end
          amm_if_v.waitrequest <= 1'b0;
          if( trans_amount > 1 )
            @( posedge amm_if_v.clk );
          trans_amount--;
        end
      else
        @( posedge amm_if_v.clk );
    end
endtask : wr_data

//****************************************************
// Read transaction tasks
//****************************************************

local task automatic rd_mem(
  int unsigned  rd_addr,
  int           bytes_amount
);
  int transaction_amount  = ( bytes_amount / MEM_DATA_B_W );
  int delay_ticks         = $dist_poisson( seed, DELAY_MEAN_VAL ) + MEM_DELAY; // "+ MEM_DELAY" because of delay to receive and process read transaction in memory chip
 
  repeat( delay_ticks )
    @( posedge amm_if_v.clk );
  repeat( transaction_amount )
    begin
      @( posedge amm_if_v.clk );
      repeat( MEM_DATA_B_W )
        begin
          if( memory_array.exists( rd_addr ) )
            rd_data_channel.push_back( memory_array[rd_addr] );
          else
            rd_data_channel.push_back( 8'h00 );
          rd_addr++;
        end
    end
endtask : rd_mem

local task automatic rd_data();
  int unsigned  rd_addr;
  int           bytes_amount;

  if( ADDR_TYPE == "BYTE" )
    rd_addr = amm_if_v.address;
  else
    rd_addr = amm_if_v.address * DATA_B_W;
  bytes_amount  = amm_if_v.burstcount * DATA_B_W;
  amm_if_v.waitrequest <= 1'b1;
  rd_mem( rd_addr, bytes_amount );
  amm_if_v.waitrequest <= 1'b0;
endtask : rd_data

local task automatic send_data();
  forever
    begin
      @( posedge amm_if_v.clk );
      amm_if_v.readdatavalid <= 1'b0;
      if( rd_data_channel.size() >= DATA_B_W )
        begin
          for( int i = 0; i < DATA_B_W; i++ )
            amm_if_v.readdata[7 + 8 * i -: 8] <= rd_data_channel.pop_front();
          if( RND_RVALID )
            begin
              while( $urandom_range( 1 ) )
                @( posedge amm_if_v.clk );
            end
          amm_if_v.readdatavalid <= 1'b1;
        end
    end
endtask : send_data

//****************************************************
// Error insert tasks
//****************************************************

local task automatic scan_test_mbx();
  forever
    begin
      @( test_started );
      gen2mem_mbx.get( rnd_scen_obj );
      insert_error  = rnd_scen_obj.err_enable;
      err_trans_num = rnd_scen_obj.err_trans_num;
      err_byte_num  = rnd_scen_obj.err_byte_num;
      cur_trans_num = 0;
      @( test_finished );
      mem2scb_mbx.put( rnd_scen_obj );
    end
endtask : scan_test_mbx

local function automatic bit [7 : 0] corrupt_data(
  int unsigned          wr_addr,        
  bit           [7 : 0] wr_data
);
  corrupt_data = ( ~wr_data );
  rnd_scen_obj.test_result_registers[CSR_TEST_RESULT] = 32'( 1 );
  rnd_scen_obj.test_result_registers[CSR_ERR_ADDR   ] = ( wr_addr + err_byte_num );
  rnd_scen_obj.test_result_registers[CSR_ERR_DATA   ] = { wr_data, corrupt_data };
endfunction : corrupt_data

//****************************************************
// Run task
//****************************************************

task automatic run();
  fork
    scan_test_mbx();
    send_data();
  join_none

  fork
    forever
      begin
        @( posedge amm_if_v.clk );
        if( amm_if_v.write )
          wr_data();
        else
          if( amm_if_v.read )
            rd_data();
      end
  join_none
endtask : run

endclass : amm_memory