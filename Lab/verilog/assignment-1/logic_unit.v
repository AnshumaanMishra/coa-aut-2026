module logic_unit(A, B, sel, Y);
  input [3:0] A, B;
  input [1:0] sel;
  output [4:0] Y;

  wire [4:0] I0, I1, I2, I3;
  ripple_carry_adder_4bit rca(
    .A(A),
    .B(B),
    .S(I0)
  );
  and_4bit a(
    .A(A),
    .B(B),
    .Out(I1)
  );
  or_4bit o(
    .A(A),
    .B(B),
    .Out(I2)
  );
  xor_4bit x(
    .A(A),
    .B(B),
    .Out(I3)
  );

  mux_4to1_5bit mux1(
    .I0(I0),
    .I1(I1),
    .I2(I2),
    .I3(I3),
    .sel(sel),
    .Y(Y)
  );

endmodule
