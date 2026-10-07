`timescale 1ns/1ps
module tb_lui;
  reg  [31:0] y;
  wire [31:0] out;

  lui dut (.y(y), .out(out));

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

  initial begin
    seed = 111;

    y = 32'h00001234; #1; check(out, 32'h12340000, "simple immediate");
    y = 32'h0000FFFF; #1; check(out, 32'hFFFF0000, "all ones immediate");
    y = 32'h00000000; #1; check(out, 32'h00000000, "zero");
    // the instruction path sign extends the immediate, upper half must be dropped
    y = 32'hFFFF8000; #1; check(out, 32'h80000000, "sign extended input");
    y = 32'hABCD0001; #1; check(out, 32'h00010000, "garbage in upper half");

    for (i = 0; i < 500; i = i + 1) begin
      y = $random(seed); #1;
      check(out, {y[15:0], 16'h0000}, "random");
    end

    if (errors == 0) $display("tb_lui: all %0d checks passed", checks);
    else             $display("tb_lui: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
