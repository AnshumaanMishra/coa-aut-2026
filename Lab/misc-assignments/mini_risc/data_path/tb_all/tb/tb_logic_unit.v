`timescale 1ns/1ps
module tb_logic_unit;
  reg  [31:0] x, y;
  reg  [2:0]  log_func;
  wire [31:0] log_out;

  logic_unit dut (.x(x), .y(y), .log_func(log_func), .log_out(log_out));

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
  integer i, f, seed;
  reg [31:0] expected;

  // func codes from the ISA table: AND 000, OR 001, NOT 010, NOR 011, XOR 100
  task try;
    input [31:0] a, b;
    input [2:0] f;
    begin
      x = a; y = b; log_func = f;
      #1;
      case (f)
        3'b000: expected = a & b;
        3'b001: expected = a | b;
        3'b010: expected = ~a;        // NOT only looks at x
        3'b011: expected = ~(a | b);
        3'b100: expected = a ^ b;
        default: expected = 32'h0;    // unused codes
      endcase
      check(log_out, expected, "logic output");
    end
  endtask

  initial begin
    seed = 121;

    for (f = 0; f < 8; f = f + 1) begin
      try(32'h00000000, 32'h00000000, f);
      try(32'hFFFFFFFF, 32'hFFFFFFFF, f);
      try(32'hF0F0F0F0, 32'h0FF00FF0, f);
      try(32'h12345678, 32'h00000000, f);
    end

    // NOT must ignore y completely
    try(32'h0000FFFF, 32'h00000000, 3'b010);
    try(32'h0000FFFF, 32'hFFFFFFFF, 3'b010);

    for (i = 0; i < 2000; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_logic_unit: all %0d checks passed", checks);
    else             $display("tb_logic_unit: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
