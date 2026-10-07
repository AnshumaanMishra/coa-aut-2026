`timescale 1ns/1ps
module tb_add_sub;
  reg  [31:0] x, y;
  reg         sub;
  wire [31:0] s;
  wire        ovfl;

  add_sub dut (.x(x), .y(y), .add_sub(sub), .s(s), .ovfl(ovfl));

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
  reg [31:0] exp_s;
  reg        exp_ovfl;

  task try;
    input [31:0] a, b;
    input do_sub;
    begin
      x = a; y = b; sub = do_sub;
      #1;
      if (do_sub) begin
        exp_s = a - b;
        // a - b overflows when the signs differ and the answer has b's sign
        exp_ovfl = (a[31] != b[31]) && (exp_s[31] != a[31]);
      end else begin
        exp_s = a + b;
        exp_ovfl = (a[31] == b[31]) && (exp_s[31] != a[31]);
      end
      check(s, exp_s, do_sub ? "subtract result" : "add result");
      check(ovfl, exp_ovfl, do_sub ? "subtract overflow" : "add overflow");
    end
  endtask

  initial begin
    seed = 33;

    try(5, 7, 0);
    try(5, 7, 1);
    try(7, 5, 1);
    try(0, 0, 1);
    try(32'h7FFFFFFF, 1, 0);             // add overflow
    try(32'h80000000, 1, 1);             // MIN - 1 overflows
    try(32'h7FFFFFFF, 32'hFFFFFFFF, 1);  // MAX - (-1) overflows
    try(32'h80000000, 32'h80000000, 1);  // equal, so zero and no overflow
    try(32'hFFFFFFFF, 32'hFFFFFFFF, 0);  // -1 + -1 = -2, fine
    try(0, 32'h80000000, 1);             // 0 - MIN overflows

    for (i = 0; i < 3000; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_add_sub: all %0d checks passed", checks);
    else             $display("tb_add_sub: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
