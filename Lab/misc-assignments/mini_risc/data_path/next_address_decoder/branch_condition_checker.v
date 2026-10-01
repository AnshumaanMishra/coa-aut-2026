module branch_condition_checker (
    eq,
    ne,
    gt,
    lt,
    le,
    ge,
    ovfl,
    br_type,
    is_branch,
    br_true
);
  input eq, ne, gt, lt, le, ge, ovfl, is_branch;
  input [2:0] br_type;
  output br_true;

  wire mux_out;

  mux_8to1 #(
      .WIDTH(1)
  ) condition_select (
      .I0 (1'b1),
      .I1 (eq),
      .I2 (ne),
      .I3 (lt),
      .I4 (le),
      .I5 (gt),
      .I6 (ge),
      .I7 (ovfl),
      .sel(br_type),
      .O  (mux_out)
  );

  assign br_true = mux_out & is_branch;
endmodule

