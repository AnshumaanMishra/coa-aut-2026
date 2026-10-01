module address_rom #(
  parameter integer ADDR = 32,
  parameter integer DATA = 32
) (
    clka,
    ena,
    addra,
    douta
);
  input clka, ena;
  input [ADDR-1:0] addra;
  output reg [DATA-1:0] douta;

  localparam integer SIZE = 1 << ADDR;
  reg [DATA-1:0] mem[SIZE];

  initial begin
    $readmemh("inputs/program.mem", mem);
  end

  always @(posedge clka) begin
    if(ena) begin
      douta <= mem[addra];
    end
  end

endmodule
