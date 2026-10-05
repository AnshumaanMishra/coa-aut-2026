module carry_save_adder #(
    parameter integer WIDTH = 32
) (
    A,
    B,
    C,
    S,
    Cout
);
  input [WIDTH-1:0] A, B, C;
  output [WIDTH-1:0] S;
  output [WIDTH-1:0] Cout;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : g_fa
      full_adder fa (
          .A(A[i]),
          .B(B[i]),
          .Cin(C[i]),
          .S(S[i]),
          .Cout(Cout[i])
      );
    end
  endgenerate
endmodule
