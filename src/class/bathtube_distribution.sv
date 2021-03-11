class bathtube_distribution;

static int seed = 0;

int value;
int right_edge;
int depth;

function automatic void set_edge( int right_edge );
  this.right_edge = right_edge;
  depth = $ceil( ( right_edge + 1 ) / 4 ); //double'
endfunction : set_edge

function automatic int get_value();
  void'( randomize() );
  return( value );
endfunction : get_value

function automatic void pre_randomize();
  value = $dist_exponential( seed, depth );
  if( value > right_edge )
    value = right_edge;
  if( $urandom_range( 1 ) )
    value = right_edge - value;
endfunction : pre_randomize

endclass : bathtube_distribution