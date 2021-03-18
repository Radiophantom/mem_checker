//****************************************************************//
// Class allows to set left and right edges of the distribution   //
// and get the random generated value with bathtube distribution. //
// Right edge MUST BE GREATER than left edge!!!                   //
//****************************************************************//

class bathtube_distribution;

static int seed = 0;

int value;
int right_edge;
int left_edge;
int depth;

function automatic void set_edge(
  int right_edge  = 1,
  int left_edge   = 0
);
  this.right_edge = right_edge - left_edge;
  this.left_edge  = left_edge;
  // adaptive distribution MEAN value calculate
  depth = $ceil( ( this.right_edge + 1 ) / 8 );
  // 0 value is prohibited by $dist_exponential()
  if( depth == 0 )
  	depth = 1;
endfunction : set_edge

function automatic int get_value();
  void'( randomize() );
  return( value );
endfunction : get_value

function automatic void pre_randomize();
  value = $dist_exponential( seed, depth );
  if( value > right_edge )
    value = right_edge;
  // random branch choise to create two-side distribution
  if( $urandom_range( 1 ) )
    value = right_edge - value;
  // add left edge to shift default distribution
  value += left_edge;
endfunction : pre_randomize

endclass : bathtube_distribution