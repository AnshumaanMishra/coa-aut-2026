module arithmetic_unit (
    x,
    y,
    arith_func,
    ovfl,
    arith_low_out,
    arith_hi_out
);
  input [31:0] x, y;
  input [2:0] arith_func;
  output ovfl;
  output [31:0] arith_hi_out, arith_low_out;

  wire [31:0] add_out, sub_out, mul_hi, mul_lo;
  wire mul_ovfl, add_ovfl, sub_ovfl;

  add_sub add (
      .x(x),
      .y(y),
      .add_sub(1'b0),
      .s(add_out),
      .ovfl(add_ovfl)
  );

  add_sub sub (
      .x(x),
      .y(y),
      .add_sub(1'b1),
      .s(sub_out),
      .ovfl(sub_ovfl)
  );

  multiplier mul (
      .x(x),
      .y(y),
      .ovfl(mul_ovfl),
      .mul_hi_out(mul_hi),
      .mul_lo_out(mul_lo)
  );

  assign arith_hi_out = mul_hi;

  mux_8to1 #(
      .WIDTH(32)
  ) arith_out_mux (
      .I0 (add_out),
      .I1 (sub_out),
      .I2 (mul_lo),
      .I3 (mul_lo),
      .I4 (32'b0),
      .I5 (32'b0),
      .I6 (32'b0),
      .I7 (32'b0),
      .sel(arith_func),
      .O  (arith_low_out)
  );

  mux_8to1 #(
      .WIDTH(1)
  ) arith_ovfl_mux (
      .I0 (add_ovfl),
      .I1 (sub_ovfl),
      .I2 (mul_ovfl),
      .I3 (mul_ovfl),
      .I4 (1'b0),
      .I5 (1'b0),
      .I6 (1'b0),
      .I7 (1'b0),
      .sel(arith_func),
      .O  (ovfl)
  );

endmodule
