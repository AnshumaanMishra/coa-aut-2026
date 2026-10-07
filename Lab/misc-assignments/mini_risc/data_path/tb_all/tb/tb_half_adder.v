`timescale 1ns/1ps
module tb_half_adder;
  reg A, B;
  wire S, C;

  half_adder dut (.A(A), .B(B), .S(S), .C(C));

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

  initial begin
    for (n = 0; n < 4; n = n + 1) begin
      {A, B} = n; #1;
      check(S, A ^ B, "sum bit");
      check(C, A & B, "carry bit");
    end

    if (errors == 0) $display("tb_half_adder: all %0d checks passed", checks);
    else             $display("tb_half_adder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
