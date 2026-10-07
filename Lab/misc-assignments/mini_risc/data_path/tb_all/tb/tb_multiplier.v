`timescale 1ns/1ps
module tb_multiplier;
  reg  [31:0] x, y;
  wire        ovfl;
  wire [31:0] hi, lo;

  multiplier dut (.x(x), .y(y), .ovfl(ovfl), .mul_hi_out(hi), .mul_lo_out(lo));

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
  integer i, j, seed;
  reg signed [63:0] p;
  reg [31:0] corners [0:11];

  // ovfl on this block is just the carry out of the last adder, which doesn't
  // mean anything for a signed product, so it is not checked here.
  task try;
    input [31:0] a, b;
    begin
      x = a; y = b;
      #1;
      p = $signed(a) * $signed(b);
      check({hi, lo}, p, "64 bit product");
    end
  endtask

  initial begin
    seed = 88;

    corners[0]  = 32'h00000000;
    corners[1]  = 32'h00000001;
    corners[2]  = 32'hFFFFFFFF;
    corners[3]  = 32'h7FFFFFFF;
    corners[4]  = 32'h80000000;
    corners[5]  = 32'h80000001;
    corners[6]  = 32'h00010000;
    corners[7]  = 32'h0000FFFF;
    corners[8]  = 32'hFFFF0000;
    corners[9]  = 32'h55555555;
    corners[10] = 32'hAAAAAAAA;
    corners[11] = 32'h00000002;

    for (i = 0; i < 12; i = i + 1)
      for (j = 0; j < 12; j = j + 1)
        try(corners[i], corners[j]);

    try(5, 7);
    try(32'hFFFFFFFD, 5);     // -3 * 5
    try(1000000, 3000);       // doesn't fit in 31 bits, still positive
    try(32'h80000000, 32'h80000000);

    for (i = 0; i < 400; i = i + 1)
      try($random(seed), $random(seed));

    if (errors == 0) $display("tb_multiplier: all %0d checks passed", checks);
    else             $display("tb_multiplier: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
