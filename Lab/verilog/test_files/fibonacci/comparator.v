module comparator(I, O);
  input [7:0] I;
  output O;

  assign O = I > 8'b0;
endmodule
