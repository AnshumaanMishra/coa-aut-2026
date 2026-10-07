`timescale 1ns/1ps
module tb_alu;
  reg  [31:0] x, y;
  reg  [5:0]  alu_func;
  reg         hi_lo_enable;
  wire        ovfl, lt, gt, le, ge, eq, ne;
  wire [31:0] alu_out_hi, alu_out_lo;

  alu dut (
    .x(x), .y(y), .alu_func(alu_func), .hi_lo_enable(hi_lo_enable),
    .ovfl(ovfl), .alu_out_hi(alu_out_hi), .alu_out_lo(alu_out_lo),
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
  // alu_func[5:3] picks the unit, alu_func[2:0] the operation inside it
  localparam [5:0]
    F_LUI = 6'b000000,
    F_SLT = 6'b001000, F_SGT = 6'b001001, F_SLE = 6'b001010,
    F_SGE = 6'b001011, F_SEQ = 6'b001100, F_SNE = 6'b001101,
    F_ADD = 6'b010000, F_SUB = 6'b010001, F_MUL = 6'b010010, F_MULU = 6'b010011,
    F_AND = 6'b011000, F_OR  = 6'b011001, F_NOT = 6'b011010,
    F_NOR = 6'b011011, F_XOR = 6'b011100,
    F_SLL = 6'b100000, F_SRL = 6'b100001, F_SRA = 6'b100010;

  integer i, j, f, seed;
  reg [31:0] corners [0:7];
  reg [31:0] e_lo, e_hi, sum;
  reg signed [63:0] prod;
  reg e_ovfl;

  // expected low result for a function code
  function [31:0] model_lo;
    input [5:0] fn;
    input [31:0] a, b;
    reg signed [63:0] p;
    begin
      p = $signed(a) * $signed(b);
      case (fn[5:3])
        3'b000: model_lo = {b[15:0], 16'h0};
        3'b001: case (fn[2:0])
                  3'd0: model_lo = ($signed(a) <  $signed(b));
                  3'd1: model_lo = ($signed(a) >  $signed(b));
                  3'd2: model_lo = ($signed(a) <= $signed(b));
                  3'd3: model_lo = ($signed(a) >= $signed(b));
                  3'd4: model_lo = (a == b);
                  3'd5: model_lo = (a != b);
                  default: model_lo = 0;
                endcase
        3'b010: case (fn[2:0])
                  3'd0: model_lo = a + b;
                  3'd1: model_lo = a - b;
                  3'd2, 3'd3: model_lo = p[31:0];
                  default: model_lo = 0;
                endcase
        3'b011: case (fn[2:0])
                  3'd0: model_lo = a & b;
                  3'd1: model_lo = a | b;
                  3'd2: model_lo = ~a;
                  3'd3: model_lo = ~(a | b);
                  3'd4: model_lo = a ^ b;
                  default: model_lo = 0;
                endcase
        3'b100: case (fn[2:0])
                  3'd0: model_lo = a << b[4:0];
                  3'd1: model_lo = a >> b[4:0];
                  3'd2: model_lo = $signed(a) >>> b[4:0];
                  default: model_lo = 0;
                endcase
        default: model_lo = 0;   // groups 101, 110, 111 aren't wired to anything
      endcase
    end
  endfunction

  task try;
    input [5:0] fn;
    input [31:0] a, b;
    input hl;
    begin
      x = a; y = b; alu_func = fn; hi_lo_enable = hl;
      #1;

      e_lo = model_lo(fn, a, b);
      check(alu_out_lo, e_lo, "alu_out_lo");

      // upper word only comes out when hi_lo_enable is set
      prod = $signed(a) * $signed(b);
      e_hi = hl ? prod[63:32] : 32'h0;
      check(alu_out_hi, e_hi, "alu_out_hi");

      // overflow only reported for add and sub
      if (fn == F_ADD) begin
        sum = a + b;
        e_ovfl = (a[31] == b[31]) && (sum[31] != a[31]);
      end else if (fn == F_SUB) begin
        sum = a - b;
        e_ovfl = (a[31] != b[31]) && (sum[31] != a[31]);
      end else
        e_ovfl = 1'b0;
      if (fn[5:3] != 3'b010 || fn[2:0] <= 3'd1 || fn[2:0] >= 3'd4)
        check(ovfl, e_ovfl, "ovfl");

      // flags always compare x with y no matter which function is selected
      check(lt, ($signed(a) <  $signed(b)), "lt");
      check(gt, ($signed(a) >  $signed(b)), "gt");
      check(le, ($signed(a) <= $signed(b)), "le");
      check(ge, ($signed(a) >= $signed(b)), "ge");
      check(eq, (a == b), "eq");
      check(ne, (a != b), "ne");
    end
  endtask

  initial begin
    seed = 161;

    corners[0] = 32'h00000000;
    corners[1] = 32'h00000001;
    corners[2] = 32'hFFFFFFFF;
    corners[3] = 32'h7FFFFFFF;
    corners[4] = 32'h80000000;
    corners[5] = 32'h0000FFFF;
    corners[6] = 32'h12345678;
    corners[7] = 32'h0000001F;

    // every function code (all 64) against corner operands
    for (f = 0; f < 64; f = f + 1)
      for (i = 0; i < 5; i = i + 1)
        for (j = 0; j < 5; j = j + 1)
          try(f, corners[i], corners[j], 0);

    // a few hand picked ones so a failure is easy to read
    try(F_ADD, 5, 7, 0);
    try(F_SUB, 5, 7, 0);
    try(F_ADD, 32'h7FFFFFFF, 1, 0);
    try(F_SUB, 32'h80000000, 1, 0);
    try(F_LUI, 0, 32'h00001234, 0);
    try(F_SLT, 32'hFFFFFFFD, 5, 0);
    try(F_SRA, 32'h80000000, 4, 0);
    try(F_MULU, 32'hFFFFFFFD, 5, 1);   // -3 * 5, hi should be all ones
    try(F_MULU, 32'h00010000, 32'h00010000, 1);
    try(F_MULU, 32'h00010000, 32'h00010000, 0);  // hi masked off

    for (i = 0; i < 800; i = i + 1)
      try($random(seed), $random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_alu: all %0d checks passed", checks);
    else             $display("tb_alu: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
