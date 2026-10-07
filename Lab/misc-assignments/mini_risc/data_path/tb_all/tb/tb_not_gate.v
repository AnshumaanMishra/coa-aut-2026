`timescale 1ns/1ps
module tb_not_gate;
  reg  [31:0] x;
  wire [31:0] out;

  not_gate dut (.x(x), .out(out));

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
  reg [31:0] expected;

  initial begin
    seed = 101;

    x = 32'h00000000; #1; check(out, 32'hFFFFFFFF, "not of zero");
    x = 32'hFFFFFFFF; #1; check(out, 32'h00000000, "not of all ones");
    x = 32'hAAAAAAAA; #1; check(out, 32'h55555555, "not of alternating bits");
    x = 32'h0000FFFF; #1; check(out, 32'hFFFF0000, "not of low half");

    for (i = 0; i < 1000; i = i + 1) begin
      x = $random(seed); #1;
      expected = ~x;
      check(out, expected, "random not");
    end

    if (errors == 0) $display("tb_not_gate: all %0d checks passed", checks);
    else             $display("tb_not_gate: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
