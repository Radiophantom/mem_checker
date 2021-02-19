module fifo #(
  parameter int AWIDTH = 4
)(
  input                 clk_i,
  input                 srst_i,

  input                 wrreq_i,
  input  cmp_struct_t   data_i,

  input                 rdreq_i,
  output cmp_struct_t   q_o,

  output logic          empty_o, 
  output logic          full_o
);

localparam FIFO_DEPTH = 2**AWIDTH;

cmp_struct_t [FIFO_DEPTH - 1 : 0] mem;

logic [AWIDTH - 1 : 0] rd_ptr;
logic [AWIDTH - 1 : 0] wr_ptr;

always_ff @( posedge clk_i )
  if( srst_i )
    full_o <= 1'b0;
  else
    if( rdreq_i )
      full_o <= 1'b0;
    else
      if( wrreq_i && ( usedw_o == ( FIFO_DEPTH - 1) ) )
        full_o <= 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    wr_ptr <= '0;
  else
    if( wrreq_i )
      wr_ptr <= wr_ptr + 1'b1;

always_ff @( posedge clk_i )
  if( srst_i )
    rd_ptr <= '0;
  else
    if( rdreq_i )
      rd_ptr <= rd_ptr + 1'b1;

always_ff @( posedge clk_i )
  if( wrreq_i )
    mem[wr_ptr] <= data_i;

always_ff @( posedge clk_i )
  if( rdreq_i )
    q_o <= mem[rd_ptr];

always_ff @( posedge clk_i )
  if( srst_i )
    empty_o <= 1'b1;
  else
    if( wrreq_i )
      empty_o <= 1'b0;
    else
      if( rdreq_i && ( usedw_o == 1 ) )
        empty_o <= 1'b1;

endmodule : fifo
