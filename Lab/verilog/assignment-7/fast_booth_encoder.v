module add_sub(I0, I1, add, O);
  input signed [31:0] I0, I1;
  input add;
  output signed [31:0] O;

  assign O = (add) ? (I0 + I1) : (I0 - I1);
endmodule

module mux(I0, I1, sel, O);
  input signed [31:0] I0, I1;
  input sel;
  output signed [31:0] O;

  assign O = (sel) ? I1 : I0;
endmodule

module fast_booth_encoder(M, Y, shift, O);
  input signed [31:0] M;
  input [2:0] Y;
  input [3:0] shift;
  output signed [31:0] O;

  wire sel1, sel2, add1, add2;
  assign sel1 = ~((&Y) | (&(~(Y))));
  assign add1 = ~Y[2];
  assign sel2 = (~Y[2] & Y[1] & Y[0]) | (Y[2] & ~Y[1] & ~Y[0]);
  assign add2 = ~Y[2];

  wire signed [31:0] mux1_out, mux2_out, out1, out2;

  mux M1(
    .I0(32'b0),
    .I1(M),
    .sel(sel1),
    .O(mux1_out)
  );

  mux M2(
    .I0(32'b0),
    .I1(M),
    .sel(sel2),
    .O(mux2_out)
  );

  add_sub A1(
    .I0(32'b0),
    .I1(mux1_out),
    .add(add1),
    .O(out1)
  );

  add_sub A2(
    .I0(out1),
    .I1(mux2_out),
    .add(add2),
    .O(out2)
  );

  assign O = out2 <<< shift;
endmodule
