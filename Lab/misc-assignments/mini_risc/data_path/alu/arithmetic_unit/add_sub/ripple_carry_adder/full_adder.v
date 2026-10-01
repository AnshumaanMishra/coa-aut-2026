module full_adder(A, B, Cin, S, Cout);
  input A, B, Cin;
  output S, Cout;

  wire sum_1, carry_1, carry_2;
  half_adder ha1(
    .A(A),
    .B(B),
    .S(sum_1),
    .C(carry_1)
  );

  half_adder ha2(
    .A(sum_1),
    .B(Cin),
    .S(S),
    .C(carry_2)
  );

  assign Cout = carry_1 | carry_2;

endmodule
