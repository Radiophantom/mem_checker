interface amm_if#(
  parameter int ADDR_W  = 4,
  parameter int DATA_W  = 31,
  parameter int BURST_W = 11
)(
  input bit clk
);

logic                       read;
logic                       write;
logic                       readdatavalid;
logic                       waitrequest;
logic [ADDR_W - 1     : 0]  address;
logic [DATA_W - 1     : 0]  writedata;
logic [DATA_W - 1     : 0]  readdata;
logic [BURST_W - 1    : 0]  burstcount;
logic [DATA_W / 8 - 1 : 0]  byteenable;

modport csr(
  output address,
  output read,
  output write,
  output writedata,
  input  readdatavalid,
  input  readdata
);

modport mem(
  input  address,
  input  read,
  input  write,
  input  writedata,
  input  byteenable,
  input  burstcount,
  output readdatavalid,
  output readdata,
  output waitrequest
);

endinterface : amm_if