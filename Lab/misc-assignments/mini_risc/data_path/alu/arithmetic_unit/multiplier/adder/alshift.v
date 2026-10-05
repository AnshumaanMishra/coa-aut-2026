module alshift #(
    parameter integer WIDTH = 32
) (
    I,
    n,
    O
);
  input [WIDTH-1:0] I;
  input [31:0] n;
  output [WIDTH-1:0] O;

  assign O = I << n;
endmodule
