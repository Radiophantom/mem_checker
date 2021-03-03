import rtl_settings_pkg::*;
import tb_settings_pkg::*;

class amm_slave_memory();

bit [7 : 0] memory_array [*];
bit [7 : 0] rd_data [$];

event test_started;
event test_finished;

random_scenario         rnd_scen_obj;

test_result_t     test_result;

int cur_trans_num = 0;
int err_trans_num = 0;

int insert_error   = 0;

local function automatic void wr_mem(
      int unsigned          wr_addr,
  ref bit           [7 : 0] wr_data [$]
);
  while( wr_data.size() )
    begin
      memory_array[wr_addr] = wr_data.pop_front();
      wr_addr++;
    end
endfunction : wr_mem

local task automatic rd_mem(
      int unsigned          rd_addr,
      int                   bytes_amount,
  ref bit           [7 : 0] rd_data [$]
);
  repeat( $urandom_range( MIN_DELAY_PARAM, MAX_DELAY_PARAM ) )
    @( posedge amm_if_v.clk );
  repeat( bytes_amount )
    begin
      rd_data.push_back( memory_array[rd_addr] ); // if address doesn't exist return 0 by default
      rd_addr++;
    end
endtask : rd_mem

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
  mailbox mem2scoreb_mbx,
  event   test_started,
  event   test_finished
);
  this.amm_if_v       = amm_if_v;
  this.gen2mem_mbx    = gen2mem_mbx;
  this.mem2scoreb_mbx = mem2scoreb_mbx;
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

local function automatic int start_offset(
  ref bit [DATA_B_W - 1 : 0] byteenable
);
  for( int i = 0; i < DATA_B_W; i++ )
    if( byteenable[i] )
      return i;
endfunction : start_offset

local task automatic void scan_test_mbx();
  forever
    begin
      wait( test_started.triggered );
      gen2mem_mbx.get( rnd_scen_obj );
      insert_error  = rnd_scen_obj.err_enable;
      err_trans_num = rnd_scen_obj.err_trans_num;
      cur_trans_num = 0;
      wait( test_finished.triggered );
      mem2scoreb_mbx.put( test_result );
    end
endtask : scan_test_mbx

local function automatic void corrupt_data(
  ref bit [7 : 0] wr_data [$]
);
  test_result[CSR_ERR_ADDR] = bath_dist_obj.value;
  test_result[CSR_ERR_DATA] = wr_data[bath_dist_obj.value];
  wr_data[bath_dist_obj.value]  = ( !wr_data[bath_dist_obj.value] );
  test_result[CSR_ERR_DATA] = wr_data[bath_dist_obj.value];
endfunction : corrupt_data

local task automatic send_data(
  ref bit [7 : 0] rd_data [$]
);
  wait( rd_data.size() > 0 );
  while( rd_data.size() )
    begin
      for( int i = 0; i < DATA_B_W; i++ )
        amm_if_v.readdata[7 + 8*i -: 8] <= rd_data.pop_front();
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
endtask : send_data

local task automatic wr_data();

  int unsigned          wr_addr;
  bit           [7 : 0] wr_data [$];
  int                   bytes_amount;

  cur_transaction_num++;
  if( ADDR_TYPE == "BYTE" )
    begin
      wr_addr       = amm_if_v.address + start_offset( amm_if_v.byteenable );
      bytes_amount  = amm_if_v.burstcount;
    end
  else
    if( ADDR_TYPE == "WORD" )
      begin
        wr_addr       = amm_if_v.address * DATA_B_W;
        bytes_amount  = amm_if_v.burstcount * DATA_B_W;
      end
  while( 1 )
    begin
      wait( amm_if_v.write );
      for( int i = 0; i < DATA_B_W; i++ )
        if( amm_if_v.byteenable[i] && bytes_amount > 0 )
          begin
            wr_data.push_back( amm_if_v.writedata[7 + 8*i -: 8] );
            bytes_amount--;
          end
      if( RND_WAITREQ )
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
      else
        break;
    end
  if( insert_err_enable )
    if( cur_transaction_num == err_transaction_num )
      begin
        corrupt_data( wr_data );
        err_struct.addr += wr_addr;
        err_trans_ans_mbx.put( err_struct );
        insert_err_enable = 0;
      end
  wr_mem( wr_addr, wr_data );
endtask

local task automatic rd_data();

  int unsigned  rd_addr;
  int           bytes_amount;

  if( ADDR_TYPE == "BYTE" )
    rd_addr  = amm_if_v.address;
  else
    rd_addr  = amm_if_v.address * DATA_B_W;
  bytes_amount = amm_if_v.burstcount * DATA_B_W;
  if( RND_WAITREQ )
    begin
      amm_if_v.waitrequest <= $urandom_range( 1 );
      while( amm_if_v.waitrequest )
        begin
          @( posedge amm_if_v.clk );
          amm_if_v.waitrequest <= $urandom_range( 1 );
        end
    end
  rd_mem( rd_addr, bytes_amount );
endtask

local task automatic run();

  scan_err_transaction();

  forever
    fork
      begin : rd_data_channel
        send_data( rd_data );
      end
      begin : wr_rd_request_channel
        @( posedge amm_if_v.clk );
        if( amm_if_v.write )
          wr_data();
        else
          if( amm_if_v.read )
            rd_data();
      end
    join_none

endtask

endclass
