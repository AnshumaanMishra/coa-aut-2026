module mux_2to1 #(parameter integer WIDTH = 32) (I0, I1, sel, O);
  input [WIDTH-1:0] I0, I1;
  input sel;
  output [WIDTH-1:0] O;

  assign O = (sel) ? I1 : I0;
endmodule
