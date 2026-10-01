module alu (
    x,
    y,
    alu_func,
    hi_lo_enable,
    ovfl,
    alu_out_hi,
    alu_out_lo,
    lt,
    gt,
    le,
    ge,
    eq,
    ne
);
  input [31:0] x, y;
  input [5:0] alu_func;
  input hi_lo_enable;
  output ovfl;
  output lt, gt, le, ge, eq, ne;
  output [31:0] alu_out_hi, alu_out_lo;

  wire au_ovfl;
  wire [31:0] au_out_lo, au_out_hi, log_out, lui_out, cmp_out, shift_out;

  lui load_upper (
      .y  (y),
      .out(lui_out)
  );

  arithmetic_unit au (
      .x(x),
      .y(y),
      .arith_func(alu_func[2:0]),
      .ovfl(au_ovfl),
      .arith_low_out(au_out_lo),
      .arith_hi_out(au_out_hi)
  );

  logic_unit lu (
      .x(x),
      .y(y),
      .log_func(alu_func[2:0]),
      .log_out(log_out)
  );

  compare_unit cu (
      .x(x),
      .y(y),
      .cmp_func(alu_func[2:0]),
      .cmp_out(cmp_out),
      .lt(lt),
      .gt(gt),
      .le(le),
      .ge(ge),
      .eq(eq),
      .ne(ne)
  );

  shift_unit su (
      .x(x),
      .y(y),
      .shift_func(alu_func[2:0]),
      .shift_out(shift_out)
  );

  mux_8to1 #(
      .WIDTH(32)
  ) alu_out_lo_mux (
      .I0 (lui_out),
      .I1 (cmp_out),
      .I2 (au_out_lo),
      .I3 (log_out),
      .I4 (shift_out),
      .I5 (32'b0),
      .I6 (32'b0),
      .I7 (32'b0),
      .sel(alu_func[5:3]),
      .O  (alu_out_lo)
  );

  mux_2to1 #(
      .WIDTH(32)
  ) alu_out_hi_mux (
      .I0 (32'b0),
      .I1 (au_out_hi),
      .sel(hi_lo_enable),
      .O  (alu_out_hi)
  );

  mux_8to1 #(
      .WIDTH(1)
  ) overflow_mux (
      .I0 (1'b0),
      .I1 (1'b0),
      .I2 (au_ovfl),
      .I3 (1'b0),
      .I4 (1'b0),
      .I5 (1'b0),
      .I6 (1'b0),
      .I7 (1'b0),
      .sel(alu_func[5:3]),
      .O  (ovfl)
  );

endmodule







