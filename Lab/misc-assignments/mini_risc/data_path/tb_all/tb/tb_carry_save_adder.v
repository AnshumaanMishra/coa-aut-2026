`timescale 1ns/1ps
module tb_carry_save_adder;
  reg  [63:0] A, B, C;
  wire [63:0] S, Cout;

  reg  [7:0] a8, b8, c8;
  wire [7:0] s8, co8;

  carry_save_adder #(.WIDTH(64)) dut64 (.A(A), .B(B), .C(C), .S(S), .Cout(Cout));
  carry_save_adder #(.WIDTH(8))  dut8  (.A(a8), .B(b8), .C(c8), .S(s8), .Cout(co8));

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

  task try;
    input [63:0] a, b, c;
    begin
      A = a; B = b; C = c;
      a8 = a[7:0]; b8 = b[7:0]; c8 = c[7:0];
      #1;
      // per bit: sum is parity, carry is majority
      check(S,    a ^ b ^ c, "sum vector");
      check(Cout, (a & b) | (a & c) | (b & c), "carry vector");
      // the real point of a CSA: S + (Cout << 1) equals A + B + C
      check(S + (Cout << 1), a + b + c, "S + 2*Cout == A+B+C");
      check(s8, (a[7:0] ^ b[7:0] ^ c[7:0]), "8 bit sum vector");
      check(co8, (a[7:0] & b[7:0]) | (a[7:0] & c[7:0]) | (b[7:0] & c[7:0]), "8 bit carry vector");
    end
  endtask

  initial begin
    seed = 55;

    try(0, 0, 0);
    try(64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF);
    try(64'h1, 64'h1, 64'h1);
    try(64'hAAAAAAAAAAAAAAAA, 64'h5555555555555555, 0);

    for (i = 0; i < 2000; i = i + 1)
      try({$random(seed), $random(seed)}, {$random(seed), $random(seed)}, {$random(seed), $random(seed)});

    if (errors == 0) $display("tb_carry_save_adder: all %0d checks passed", checks);
    else             $display("tb_carry_save_adder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
