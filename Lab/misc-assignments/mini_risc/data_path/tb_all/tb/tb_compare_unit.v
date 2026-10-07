`timescale 1ns/1ps
module tb_compare_unit;
  reg  [31:0] x, y;
  reg  [2:0]  cmp_func;
  wire [31:0] cmp_out;
  wire        lt, gt, le, ge, eq, ne;

  compare_unit dut (
    .x(x), .y(y), .cmp_func(cmp_func), .cmp_out(cmp_out),
    .lt(lt), .gt(gt), .le(le), .ge(ge), .eq(eq), .ne(ne));

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
  reg [31:0] corners [0:8];
  reg e_lt, e_gt, e_le, e_ge, e_eq, e_ne;
  reg [31:0] e_out;

  task try;
    input [31:0] a, b;
    input [2:0] f;
    begin
      x = a; y = b; cmp_func = f;
      #1;
      e_lt = ($signed(a) <  $signed(b));
      e_gt = ($signed(a) >  $signed(b));
      e_le = ($signed(a) <= $signed(b));
      e_ge = ($signed(a) >= $signed(b));
      e_eq = (a == b);
      e_ne = (a != b);

      check(lt, e_lt, "lt flag");
      check(gt, e_gt, "gt flag");
      check(le, e_le, "le flag");
      check(ge, e_ge, "ge flag");
      check(eq, e_eq, "eq flag");
      check(ne, e_ne, "ne flag");

      // SLT 000, SGT 001, SLE 010, SGE 011, SEQ 100, SNE 101
      case (f)
        3'd0: e_out = e_lt;
        3'd1: e_out = e_gt;
        3'd2: e_out = e_le;
        3'd3: e_out = e_ge;
        3'd4: e_out = e_eq;
        3'd5: e_out = e_ne;
        default: e_out = 0;
      endcase
      check(cmp_out, e_out, "cmp_out");
    end
  endtask

  initial begin
    seed = 141;

    corners[0] = 32'h00000000;
    corners[1] = 32'h00000001;
    corners[2] = 32'hFFFFFFFF;
    corners[3] = 32'h7FFFFFFF;
    corners[4] = 32'h80000000;
    corners[5] = 32'h80000001;
    corners[6] = 32'h0000FFFF;
    corners[7] = 32'hFFFF0000;
    corners[8] = 32'h12345678;

    // MIN vs MAX and friends are the interesting ones: a - b overflows there
    // and a plain sign-bit check would give the wrong answer
    for (i = 0; i < 9; i = i + 1)
      for (j = 0; j < 9; j = j + 1)
        for (f = 0; f < 8; f = f + 1)
          try(corners[i], corners[j], f);

    for (i = 0; i < 3000; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_compare_unit: all %0d checks passed", checks);
    else             $display("tb_compare_unit: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
