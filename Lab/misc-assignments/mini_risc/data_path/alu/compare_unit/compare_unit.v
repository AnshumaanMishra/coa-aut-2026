module compare_unit (
    x,
    y,
    cmp_func,
    cmp_out,
    lt,
    gt,
    le,
    ge,
    eq,
    ne
);
  input [31:0] x, y;
  input [2:0] cmp_func;
  output [31:0] cmp_out;
  output lt, gt, le, ge, eq, ne;

  wire [31:0] sub_result;
  wire sub_ovfl;
  wire [31:0] lt_out, gt_out, le_out, ge_out, eq_out, ne_out;

  add_sub sub (
      .x(x),
      .y(y),
      .add_sub(1'b1),
      .s(sub_result),
      .ovfl(sub_ovfl)
  );

  xor (lt, sub_result[31], sub_ovfl);

  assign eq = ~|sub_result;

  not (ne, eq);
  not (ge, lt);
  and (gt, ge, ne);
  or (le, lt, eq);

  assign lt_out = {31'b0, lt};
  assign gt_out = {31'b0, gt};
  assign le_out = {31'b0, le};
  assign ge_out = {31'b0, ge};
  assign eq_out = {31'b0, eq};
  assign ne_out = {31'b0, ne};

  mux_8to1 #(
      .WIDTH(32)
  ) cmp_mux (
      .I0 (lt_out),
      .I1 (gt_out),
      .I2 (le_out),
      .I3 (ge_out),
      .I4 (eq_out),
      .I5 (ne_out),
      .I6 (32'b0),
      .I7 (32'b0),
      .sel(cmp_func),
      .O  (cmp_out)
  );

endmodule




