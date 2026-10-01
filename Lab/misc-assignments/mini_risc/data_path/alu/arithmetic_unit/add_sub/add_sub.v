module add_sub (
    x,
    y,
    add_sub,
    s,
    ovfl
);
  input [31:0] x, y;
  input add_sub;
  output [31:0] s;
  output ovfl;

  wire [31:0] y_in;
  wire [31:0] xor_op;
  wire cout;

  assign xor_op = {32{add_sub}};
  assign y_in   = y ^ xor_op;

  ripple_carry_adder rca (
      .x(x),
      .y(y_in),
      .cin(add_sub),
      .s(s),
      .ovfl(ovfl)
  );

endmodule

