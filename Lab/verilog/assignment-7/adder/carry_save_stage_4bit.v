module carry_save_stage_4bit(A, B, C, S, Cout);
  input [3:0] A, B, C;
  output [3:0] S, Cout;

  full_adder fa1(
    .A(A[0]),
    .B(B[0]),
    .Cin(C[0]),
    .S(S[0]),
    .Cout(Cout[0])
  );
  full_adder fa2(
    .A(A[1]),
    .B(B[1]),
    .Cin(C[1]),
    .S(S[1]),
    .Cout(Cout[1])
  );
  full_adder fa3(
    .A(A[2]),
    .B(B[2]),
    .Cin(C[2]),
    .S(S[2]),
    .Cout(Cout[2])
  );
  full_adder fa4(
    .A(A[3]),
    .B(B[3]),
    .Cin(C[3]),
    .S(S[3]),
    .Cout(Cout[3])
  );

endmodule
