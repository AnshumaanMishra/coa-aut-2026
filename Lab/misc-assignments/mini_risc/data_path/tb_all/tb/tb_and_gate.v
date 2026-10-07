`timescale 1ns/1ps
module tb_and_gate;
  reg  [31:0] x, y;
  wire [31:0] out;

  and_gate dut (.x(x), .y(y), .out(out));

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
    input [31:0] a, b;
    begin
      x = a; y = b;
      #1;
      check(out, a & b, "bitwise and");
    end
  endtask

  initial begin
    seed = 99;

    try(32'h00000000, 32'h00000000);
    try(32'hFFFFFFFF, 32'hFFFFFFFF);
    try(32'hFFFFFFFF, 32'h00000000);
    try(32'h00000000, 32'hFFFFFFFF);
    try(32'hAAAAAAAA, 32'h55555555);
    try(32'hF0F0F0F0, 32'hFF00FF00);

    for (i = 0; i < 1000; i = i + 1)
      try($random(seed), $random(seed));

    if (errors == 0) $display("tb_and_gate: all %0d checks passed", checks);
    else             $display("tb_and_gate: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
