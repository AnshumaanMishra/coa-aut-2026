module carry_save_adder_3x4(A, B, C, O);
  input [3:0] A, B, C;
  output [5:0] O;

  wire [3:0] S, Cout;

  carry_save_stage_4bit css(
    .A(A),
    .B(B),
    .C(C),
    .S(S),
    .Cout(Cout)
  );

  wire [4:0] S_ext, C_ext;
  assign S_ext = {1'b0, S};
  assign C_ext = {Cout, 1'b0};

  ripple_carry_adder_5bit rca(
    .A(S_ext),
    .B(C_ext),
    .S(O)
  );

endmodule
