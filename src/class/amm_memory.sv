import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class amm_memory();

random_scenario   rnd_scen_obj;

bit [7 : 0] memory_array    [*];
bit [7 : 0] rd_data_channel [$];
bit [7 : 0] wr_data_channel [$];

mailbox gen2mem_mbx;
mailbox mem2scb_mbx;

event test_started;
event test_finished;

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
  amm_if_v.byteenable     = '0;
  amm_if_v.burstcount     = '0;
endfunction : init_interface

int insert_error  = 0;
int cur_trans_num = 0;
int err_trans_num = 0;
int err_byte_num  = 0;

local task automatic wr_mem(
  int unsigned  wr_addr,
  int           bytes_amount
);
  fork
    while( bytes_amount )
      begin
        @( posedge amm_if_v.clk );
        repeat( MEM_DATA_B_W )
          if( wr_data_channel.size() )
            begin
              memory_array[wr_addr] = wr_data_channel.pop_front();
              wr_addr++;
              bytes_amount--;
            end
      end
  join_none
endtask : wr_mem

int rnd_seed = 0;

local task automatic rd_mem(
  int unsigned  rd_addr,
  int           bytes_amount
);
  int transaction_amount  = ( bytes_amount / MEM_DATA_B_W );
  int delay_ticks         = $dist_poisson( seed, DELAY_MEAN_VAL );
  repeat( delay_ticks )
    @( posedge amm_if_v.clk );
  repeat( transaction_amount )
    begin
      @( posedge amm_if_v.clk );
      repeat( MEM_DATA_B_W )
        begin
          rd_data_channel.push_back( memory_array[rd_addr] );
          rd_addr++;
        end
    end
endtask : rd_mem

local function automatic int start_offset( ref bit [DATA_B_W - 1 : 0] byteenable );
  for( int i = 0; i < DATA_B_W; i++ )
    if( byteenable[i] )
      return( i );
endfunction : start_offset

local task automatic void scan_test_mbx();
  forever
    begin
      @( test_started );  //wait( test_started.triggered );
      gen2mem_mbx.get( rnd_scen_obj );
      insert_error  = rnd_scen_obj.err_enable;
      err_byte_num  = rnd_scen_obj.err_byte_num;
      err_trans_num = rnd_scen_obj.err_trans_num;
      cur_trans_num = 0;
      @( test_finished ); //wait( test_finished.triggered );
      mem2scb_mbx.put( rnd_scen_obj );
    end
endtask : scan_test_mbx

local function automatic bit [7 : 0] corrupt_data(
  ref int unsigned          wr_addr,        
  ref bit           [7 : 0] wr_data
);
  corrupt_data = ( ~wr_data );
  rnd_scen_obj.test_result_registers[CSR_TEST_RESULT] = 32'( 1 );
  rnd_scen_obj.test_result_registers[CSR_ERR_ADDR   ] = ( wr_addr + err_byte_num );
  rnd_scen_obj.test_result_registers[CSR_ERR_DATA   ] = { wr_data, corrupt_data };
endfunction : corrupt_data

local task automatic wr_data_collect( int bytes_amount );
  int byte_num = 0;
  bit [7 : 0] wr_byte;

  while( bytes_amount )
    begin
      wait( amm_if_v.write );
      for( int i = 0; i < DATA_B_W; i++ )
        if( amm_if_v.byteenable[i] )        // check if byteenable tester behavior correct or not --"&& ( bytes_amount > 0 ) )"--
          begin
            if( insert_error && ( cur_trans_num == err_trans_num ) && ( byte_num == err_byte_num ) )
              wr_byte = corrupt_data( wr_addr, amm_if_v.writedata[7 + i * 8 -: 8] ) );
            else
              wr_byte = amm_if_v.writedata[7 + i * 8 -: 8] );
            wr_data_channel.push_back( wr_byte );
            bytes_amount--;
            byte_num++;
          end
      if( wr_data_channel.size() >= DATA_B_W )
        begin
          amm_if_v.waitrequest <= 1'b1;
          wait( wr_data_channel.size() == 0 )
        end
      if( RND_WAITREQ && ( bytes_amount > 0 ) )
        begin
          amm_if_v.waitrequest <= $urandom_range( 1 );
          while( amm_if_v.waitrequest )
            begin
              @( posedge amm_if_v.clk );
              amm_if_v.waitrequest <= $urandom_range( 1 );
            end
        end
      else
        amm_if_v.waitrequest <= 1'b0;
      if( bytes_amount )
        @( posedge amm_if_v.clk );
    end
endtask : wr_data_collect
  
local task automatic wr_data();
  int unsigned  wr_addr;
  int           bytes_amount;

  if( ADDR_TYPE == "BYTE" )
    begin
      wr_addr       = amm_if_v.address + start_offset( amm_if_v.byteenable );
      bytes_amount  = amm_if_v.burstcount;
    end
  else
    begin
      wr_addr       = amm_if_v.address    * DATA_B_W;
      bytes_amount  = amm_if_v.burstcount * DATA_B_W;
    end
  wr_mem( wr_addr, bytes_amount );
  wr_data_collect( bytes_amount );
endtask : wr_data

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
      wait( rd_data_channel.size() >= DATA_B_W );
      while( rd_data_channel.size() >= DATA_B_W )
        begin
          for( int i = 0; i < DATA_B_W; i++ )
            amm_if_v.readdata[7 + 8*i -: 8] <= rd_data_channel.pop_front();
          if( RND_RVALID )
            begin
              amm_if_v.readdatavalid <= $urandom_range( 1 );
              while( !amm_if_v.readdatavalid )
                begin
                  @( posedge amm_if_v.clk );
                  amm_if_v.readdatavalid <= $urandom_range( 1 );
                end
            end
          else
            amm_if_v.readdatavalid <= 1'b1;
          @( posedge amm_if_v.clk );
        end
      amm_if_v.readdatavalid <= 1'b0;
    end
endtask : send_data

local task automatic run();
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
