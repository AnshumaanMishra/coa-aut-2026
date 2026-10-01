module ripple_carry_adder_5bit(A, B, S);
  input [4:0] A, B;
  output [5:0] S;

  wire c1, c2, c3, c4;

  full_adder f1(
    .A(A[0]),
    .B(B[0]),
    .Cin(1'b0),
    .S(S[0]),
    .Cout(c1)
  );

  full_adder f2(
    .A(A[1]),
    .B(B[1]),
    .Cin(c1),
    .S(S[1]),
    .Cout(c2)
  );

  full_adder f3(
    .A(A[2]),
    .B(B[2]),
    .Cin(c2),
    .S(S[2]),
    .Cout(c3)
  );

  full_adder f4(
    .A(A[3]),
    .B(B[3]),
    .Cin(c3),
    .S(S[3]),
    .Cout(c4)
  );

  full_adder f5(
    .A(A[4]),
    .B(B[4]),
    .Cin(c4),
    .S(S[4]),
    .Cout(S[5])
  );
endmodule
