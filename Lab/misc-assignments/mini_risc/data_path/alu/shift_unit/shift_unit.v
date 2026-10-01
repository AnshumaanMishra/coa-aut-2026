module shift_unit (
    x,
    y,
    shift_func,
    shift_out
);
  input signed [31:0] x, y;
  input [2:0] shift_func;
  output [31:0] shift_out;

  wire [31:0] SL, SRL, SRA;
  wire [4:0] shift_amt;
  assign shift_amt = y[4:0];

  assign SL = x << shift_amt;
  assign SRL = x >> shift_amt;
  assign SRA = x >>> shift_amt;

  mux_8to1 #(
      .WIDTH(32)
  ) M (
      .I0 (SL),
      .I1 (SRL),
      .I2 (SRA),
      .I3 (32'b0),
      .I4 (32'b0),
      .I5 (32'b0),
      .I6 (32'b0),
      .I7 (32'b0),
      .sel(shift_func),
      .O  (shift_out)
  );

endmodule
