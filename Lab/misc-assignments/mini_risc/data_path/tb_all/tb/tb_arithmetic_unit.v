`timescale 1ns/1ps
module tb_arithmetic_unit;
  reg  [31:0] x, y;
  reg  [2:0]  arith_func;
  wire        ovfl;
  wire [31:0] lo, hi;

  arithmetic_unit dut (
    .x(x), .y(y), .arith_func(arith_func),
    .ovfl(ovfl), .arith_low_out(lo), .arith_hi_out(hi));

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
  integer i, j, f, seed;
  reg [31:0] corners [0:7];
  reg [31:0] e_lo;
  reg signed [63:0] prod;
  reg e_ovfl;

  // ADD 000, SUB 001, MUL 010, MULU 011. Anything above is unused.
  // hi output always carries the upper half of the product, the ALU decides
  // whether to use it.
  task try;
    input [31:0] a, b;
    input [2:0] f;
    begin
      x = a; y = b; arith_func = f;
      #1;
      prod = $signed(a) * $signed(b);

      case (f)
        3'd0: begin
          e_lo = a + b;
          e_ovfl = (a[31] == b[31]) && (e_lo[31] != a[31]);
        end
        3'd1: begin
          e_lo = a - b;
          e_ovfl = (a[31] != b[31]) && (e_lo[31] != a[31]);
        end
        3'd2, 3'd3: begin
          e_lo = prod[31:0];
          e_ovfl = ovfl;   // multiplier carry out, no meaningful reference
        end
        default: begin
          e_lo = 32'h0;
          e_ovfl = 1'b0;
        end
      endcase

      check(lo, e_lo, "low result");
      check(hi, prod[63:32], "high half");
      check(ovfl, e_ovfl, "overflow");
    end
  endtask

  initial begin
    seed = 151;

    corners[0] = 32'h00000000;
    corners[1] = 32'h00000001;
    corners[2] = 32'hFFFFFFFF;
    corners[3] = 32'h7FFFFFFF;
    corners[4] = 32'h80000000;
    corners[5] = 32'h00010000;
    corners[6] = 32'h12345678;
    corners[7] = 32'hDEADBEEF;

    for (i = 0; i < 8; i = i + 1)
      for (j = 0; j < 8; j = j + 1)
        for (f = 0; f < 8; f = f + 1)
          try(corners[i], corners[j], f);

    for (i = 0; i < 600; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_arithmetic_unit: all %0d checks passed", checks);
    else             $display("tb_arithmetic_unit: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
