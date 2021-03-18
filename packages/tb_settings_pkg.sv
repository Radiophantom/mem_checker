package tb_settings_pkg;

parameter int CLK_SYS_T 			= 10_000;
parameter int CLK_MEM_T 			= 8_000;

parameter int RND_WAITREQ   	= 0;
parameter int RND_RVALID    	= 0;

parameter int DELAY_MEAN_VAL  = 10;
parameter int MEM_DELAY 	  	= 2;

function automatic int start_offset(
  bit [127 : 0] byteenable
);
  for( int i = 0; i < 127; i++ )
    if( byteenable[i] )
      return( i );
endfunction : start_offset

endpackage : tb_settings_pkg