`timescale 1ns/1ps
module tb_ripple_carry_adder_2;
  // multiplier uses this at 64 bits, also try a small width to be safe
  reg  [63:0] A, B;
  reg         addsub;
  wire [63:0] S;
  wire        Cout;

  reg  [7:0]  a8, b8;
  wire [7:0]  s8;
  wire        c8;

  ripple_carry_adder_2 #(.WIDTH(64)) dut64 (.A(A), .B_in(B), .addsub(addsub), .S(S), .Cout(Cout));
  ripple_carry_adder_2 #(.WIDTH(8))  dut8  (.A(a8), .B_in(b8), .addsub(addsub), .S(s8), .Cout(c8));

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
  reg [64:0] exp64;
  reg [8:0]  exp8;

  task try64;
    input [63:0] a, b;
    input sub;
    begin
      A = a; B = b; addsub = sub;
      #1;
      exp64 = sub ? ({1'b0, a} + {1'b0, ~b} + 65'd1) : ({1'b0, a} + {1'b0, b});
      check(S, exp64[63:0], "64 bit sum");
      check(Cout, exp64[64], "64 bit carry out");
    end
  endtask

  task try8;
    input [7:0] a, b;
    input sub;
    begin
      a8 = a; b8 = b; addsub = sub;
      #1;
      exp8 = sub ? ({1'b0, a} + {1'b0, ~b} + 9'd1) : ({1'b0, a} + {1'b0, b});
      check(s8, exp8[7:0], "8 bit sum");
      check(c8, exp8[8], "8 bit carry out");
    end
  endtask

  initial begin
    seed = 44;

    try64(0, 0, 0);
    try64(64'hFFFFFFFFFFFFFFFF, 1, 0);
    try64(64'h00000000FFFFFFFF, 1, 0);          // carry crosses the 32 bit boundary
    try64(64'h123456789ABCDEF0, 64'h0FEDCBA987654321, 0);
    try64(100, 58, 1);
    try64(58, 100, 1);                           // negative result
    try64(64'h8000000000000000, 1, 1);

    try8(8'h00, 8'h00, 0);
    try8(8'hFF, 8'h01, 0);
    try8(8'h10, 8'h20, 1);
    try8(8'h20, 8'h10, 1);

    for (i = 0; i < 2000; i = i + 1) begin
      try64({$random(seed), $random(seed)}, {$random(seed), $random(seed)}, $random(seed));
      try8($random(seed), $random(seed), $random(seed));
    end

    if (errors == 0) $display("tb_ripple_carry_adder_2: all %0d checks passed", checks);
    else             $display("tb_ripple_carry_adder_2: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
