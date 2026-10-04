module full_adder(A, B, Cin, S, C);
  input A, B, Cin;
  output S, C;

  wire AxorB;

  xor (AxorB, A, B);
  xor (S, AxorB, Cin);

  wire AandB, BandC, CandA;
  and (AandB, A, B);
  and (BandC, B, C);
  and (CandA, C, A);

  wire ABorBC;
  or (ABorBC, AandB, BandC);
  or (C, ABorBC, CandA);

endmodule
