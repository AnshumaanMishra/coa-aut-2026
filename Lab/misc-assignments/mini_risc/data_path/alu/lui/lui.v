module lui (
    y,
    out
);
  input [31:0] y;
  output [31:0] out;

  assign out = {y[15:0], 16'b0};
endmodule
