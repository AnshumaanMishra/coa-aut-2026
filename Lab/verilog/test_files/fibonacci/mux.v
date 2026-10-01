module mux(I0, I1, sel, O);
  input [7:0] I0, I1;
  input sel;
  output [7:0] O;

  assign O = (sel) ? I1 : I0;
endmodule
