`timescale 1us/1ns

module tb_half_adder;
  reg a, b;
  wire s, c;

  half_adder ha(
    .A(a),
    .B(b),
    .S(s),
    .C(c)
  );

  initial begin
    $dumpfile("half_adder.vcd");
    $dumpvars(0, tb_half_adder);

    $monitor("A: %b;\tB: %b;\tS: %b;\tC: %b;\tTime: %t", a, b, s, c, $time);
    a = 0; b = 0; #20;
    a = 0; b = 1; #20;
    a = 1; b = 0; #20;
    a = 1; b = 1; #20;

    $finish;
  end
endmodule
