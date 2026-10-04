module ripple_carry_adder #(parameter integer WIDTH=32) (A, B, Cin, S, Cout);
  input [WIDTH-1:0] A, B;
  input Cin;
  output [WIDTH-1:0] S;
  output Cout;

  wire carry[WIDTH:0];
  assign carry[0] = Cin;
  genvar i;
  generate
    for(i = 0; i < WIDTH; i = i + 1) begin : gen_fa
      full_adder fa(
        .A(A[i]),
        .B(B[i]),
        .Cin(carry[i]),
        .S(S[i]),
        .C(carry[i + 1])
      );
    end
  endgenerate

  assign Cout = carry[WIDTH];
endmodule;
