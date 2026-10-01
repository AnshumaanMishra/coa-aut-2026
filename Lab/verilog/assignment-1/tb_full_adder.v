`timescale 1ns/1ps

module tb_full_adder;
  reg a, b, cin;
  wire s, cout;
  reg [1:0] out;
  integer i;

  full_adder fa(
    .A(a),
    .B(b),
    .Cin(cin),
    .S(s),
    .Cout(cout)
  );

  initial begin
    $dumpfile("full_adder.vcd");
    $dumpvars(0, tb_full_adder);
    $monitor(
      "A: %b\tB: %b\tCin: %b\tS: %b\tCout: %b;Output: %d;\tTime: %t\t",
      a, b, cin, s, cout, out, $time
    );
    for(i = 0; i < 8; i = i + 1) begin
      {a, b, cin} = i;
      #10;
      out = {cout, s};
    end
  end
endmodule
