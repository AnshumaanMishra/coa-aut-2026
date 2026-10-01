module decrementer(K, O);
  input [7:0] K;
  output [7:0] O;

  assign O = K - 8'b00000001;
endmodule
