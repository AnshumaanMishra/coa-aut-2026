module full_adder(A, B, Cin, S, Cout);
  input A, B, Cin;
  output S, Cout;

  wire inter_sum_1, inter_carry_1;
  wire placeholder, inter_carry_2;

  half_adder h1(
    .A(A),
    .B(B),
    .S(inter_sum_1),
    .C(inter_carry_1)
  );

  half_adder h2(
    .A(inter_sum_1),
    .B(Cin),
    .S(S),
    .C(inter_carry_2)
  );

  half_adder h3(
    .A(inter_carry_1),
    .B(inter_carry_2),
    .S(Cout),
    .C(placehodler)
  );

endmodule
