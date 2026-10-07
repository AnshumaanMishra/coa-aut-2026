`timescale 1ns/1ps
module tb_alshift;
  reg  [31:0] I;
  reg  [31:0] n;
  wire [31:0] O;

  reg  [63:0] I64;
  wire [63:0] O64;

  alshift #(.WIDTH(32)) dut   (.I(I),   .n(n), .O(O));
  alshift #(.WIDTH(64)) dut64 (.I(I64), .n(n), .O(O64));

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
  integer i, k, seed;
  reg [31:0] e;
  reg [63:0] e64;

  initial begin
    seed = 66;

    I = 32'h00000001;
    I64 = 64'h0000000000000001;
    for (n = 0; n < 70; n = n + 1) begin
      #1;
      // build the expected value by shifting one bit at a time
      e = I; e64 = I64;
      for (k = 0; k < n; k = k + 1) begin
        e = {e[30:0], 1'b0};
        e64 = {e64[62:0], 1'b0};
      end
      check(O, e, "single bit, 32 wide");
      check(O64, e64, "single bit, 64 wide");
    end

    for (i = 0; i < 500; i = i + 1) begin
      I = $random(seed);
      I64 = {$random(seed), $random(seed)};
      n = $random(seed) % 70;
      if (n > 69) n = 3;
      #1;
      e = I; e64 = I64;
      for (k = 0; k < n; k = k + 1) begin
        e = {e[30:0], 1'b0};
        e64 = {e64[62:0], 1'b0};
      end
      check(O, e, "random, 32 wide");
      check(O64, e64, "random, 64 wide");
    end

    if (errors == 0) $display("tb_alshift: all %0d checks passed", checks);
    else             $display("tb_alshift: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
