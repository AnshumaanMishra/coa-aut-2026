`timescale 1ns/1ps
module tb_full_adder;
  reg A, B, Cin;
  wire S, Cout;

  full_adder dut (.A(A), .B(B), .Cin(Cin), .S(S), .Cout(Cout));

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
  integer n;
  reg [1:0] total;

  initial begin
    // only 8 input combinations so just do all of them
    for (n = 0; n < 8; n = n + 1) begin
      {A, B, Cin} = n; #1;
      total = A + B + Cin;
      check(S, total[0], "sum bit");
      check(Cout, total[1], "carry out");
    end

    if (errors == 0) $display("tb_full_adder: all %0d checks passed", checks);
    else             $display("tb_full_adder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
