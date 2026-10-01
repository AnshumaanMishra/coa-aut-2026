module data_ram #(
    parameter integer ADDR = 32,
    parameter integer DATA = 32
) (
    clka,
    ena,
    addra,
    wea,
    dina,
    douta
);
  input clka, ena, wea;
  input [ADDR-1:0] addra;
  input [DATA-1:0] dina;
  output reg [DATA-1:0] douta;

  localparam integer SIZE = 1 << ADDR;
  reg [DATA-1:0] mem[SIZE];

  initial begin
    $readmemh("inputs/data_ram.mem", mem);
  end

  always @(posedge clka) begin
    if (ena) begin
      if (wea) begin
        mem[addra] <= dina;
      end
      douta <= mem[addra];
    end
  end

endmodule
