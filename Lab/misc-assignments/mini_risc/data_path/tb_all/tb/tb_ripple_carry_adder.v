`timescale 1ns/1ps
module tb_ripple_carry_adder;
  reg  [31:0] x, y;
  reg         cin;
  wire [31:0] s;
  wire        ovfl;

  ripple_carry_adder dut (.x(x), .y(y), .cin(cin), .s(s), .ovfl(ovfl));

  integer errors = 0;
  integer checks = 0;

  task check;
    input [63:0] got;
    input [63:0] expected;
    input [255:0] what;
    begin
      checks = checks + 1;
      if (got !== expected) begin
        errors = errors + 1;
        $display("FAIL [%0t] %0s: got %h, expected %h", $time, what, got, expected);
      end
    end
  endtask
  integer i, seed;
  reg [32:0] sum;
  reg        exp_ovfl;

  task try;
    input [31:0] a, b;
    input c;
    begin
      x = a; y = b; cin = c;
      #1;
      sum = a + b + c;
      // signed overflow: operands agree in sign but the result does not
      exp_ovfl = (a[31] == b[31]) && (sum[31] != a[31]);
      check(s, sum[31:0], "sum");
      check(ovfl, exp_ovfl, "overflow");
    end
  endtask

  initial begin
    seed = 21;

    try(0, 0, 0);
    try(0, 0, 1);
    try(1, 1, 0);
    try(32'hFFFFFFFF, 1, 0);            // carries all the way up
    try(32'hFFFFFFFF, 32'hFFFFFFFF, 1);
    try(32'h7FFFFFFF, 1, 0);            // pos + pos -> neg, overflow
    try(32'h80000000, 32'hFFFFFFFF, 0); // neg + neg -> pos, overflow
    try(32'h80000000, 32'h80000000, 0);
    try(32'h7FFFFFFF, 32'h80000000, 0); // mixed signs never overflow
    try(32'h0000FFFF, 32'h00000001, 0);
    try(32'h55555555, 32'hAAAAAAAA, 1);

    for (i = 0; i < 3000; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_ripple_carry_adder: all %0d checks passed", checks);
    else             $display("tb_ripple_carry_adder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
