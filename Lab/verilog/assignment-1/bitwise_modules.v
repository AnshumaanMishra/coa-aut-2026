module and_4bit(A, B, Out);
  input [3:0] A, B;
  output [4:0] Out;

  assign Out[0] = A[0] & B[0];
  assign Out[1] = A[1] & B[1];
  assign Out[2] = A[2] & B[2];
  assign Out[3] = A[3] & B[3];
  assign Out[4] = 1'b0;
endmodule


module or_4bit(A, B, Out);
  input [3:0] A, B;
  output [4:0] Out;

  assign Out[0] = A[0] | B[0];
  assign Out[1] = A[1] | B[1];
  assign Out[2] = A[2] | B[2];
  assign Out[3] = A[3] | B[3];
  assign Out[4] = 1'b0;
endmodule

module xor_4bit(A, B, Out);
  input [3:0] A, B;
  output [4:0] Out;

  assign Out[0] = A[0] ^ B[0];
  assign Out[1] = A[1] ^ B[1];
  assign Out[2] = A[2] ^ B[2];
  assign Out[3] = A[3] ^ B[3];
  assign Out[4] = 1'b0;
endmodule
