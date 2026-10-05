module ripple_carry_adder_2 #(
    parameter integer WIDTH = 32
) (
    A,
    B_in,
    addsub,
    S,
    Cout
);
  input [WIDTH-1:0] A, B_in;
  input addsub;
  output [WIDTH-1:0] S;
  output Cout;

  wire [  WIDTH:0] carry;
  wire [WIDTH-1:0] B;

  assign B = B_in ^ {WIDTH{addsub}};
  assign carry[0] = addsub;

  genvar i;
  generate
    for (i = 0; i < WIDTH; i = i + 1) begin : gen_fa
      full_adder fa (
          .A(A[i]),
          .B(B[i]),
          .Cin(carry[i]),
          .S(S[i]),
          .Cout(carry[i+1])
      );
    end
  endgenerate

  assign Cout = carry[WIDTH];
endmodule
