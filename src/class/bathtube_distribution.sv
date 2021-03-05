class bathtube_distribution();

static int seed = 0;

int value;
int right_edge;
int depth;

function automatic void set_dist_parameters(
  input int right_edge  = 1,
  input int depth       = 4
);
  this.right_edge = right_edge;
  this.depth      = depth;
endfunction : set_dist_parameters

function automatic void pre_randomize();
  value = $dist_exponential( seed, depth );
  if( value > right_edge )
    value = right_edge;

  if( $urandom_range( 1 ) )
    value = right_edge - value;

endfunction : pre_randomize

endclass : bathtube_distribution
