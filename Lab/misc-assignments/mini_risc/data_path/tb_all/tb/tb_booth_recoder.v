`timescale 1ns/1ps
module tb_booth_recoder;
  reg         Q1, Q0, Qm1;
  reg  [31:0] M;
  wire [63:0] O;

  booth_recoder #(.WIDTH(32)) dut (.Q1(Q1), .Q0(Q0), .Qm1(Qm1), .M(M), .O(O));

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
  integer i, n, seed;
  integer digit;
  reg signed [63:0] m_ext;
  reg signed [63:0] expected;

  task try;
    input [2:0] bits;
    input [31:0] m;
    begin
      {Q1, Q0, Qm1} = bits;
      M = m;
      #1;
      // radix 4 booth digit = -2*Q1 + Q0 + Qm1
      digit = -2 * bits[2] + bits[1] + bits[0];
      m_ext = {{32{m[31]}}, m};
      expected = m_ext * digit;
      check(O, expected, "partial product");
    end
  endtask

  initial begin
    seed = 77;

    // every bit triple against a few multiplicands
    for (n = 0; n < 8; n = n + 1) begin
      try(n, 32'd1);
      try(n, 32'd5);
      try(n, 32'hFFFFFFFF);   // -1
      try(n, 32'h7FFFFFFF);
      try(n, 32'h80000000);   // most negative, doubling it needs bit 32
      try(n, 32'd0);
    end

    for (i = 0; i < 1000; i = i + 1)
      try($random(seed), $random(seed));

    if (errors == 0) $display("tb_booth_recoder: all %0d checks passed", checks);
    else             $display("tb_booth_recoder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
