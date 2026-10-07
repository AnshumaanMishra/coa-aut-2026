`timescale 1ns/1ps
module tb_shift_unit;
  reg  signed [31:0] x, y;
  reg  [2:0]  shift_func;
  wire [31:0] shift_out;

  shift_unit dut (.x(x), .y(y), .shift_func(shift_func), .shift_out(shift_out));

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
  integer i, f, amt, seed;
  reg [31:0] expected;
  reg [31:0] a, b;

  // SLL 000, SRL 001, SRA 010, everything else 0. Shift amount is y[4:0].
  task try;
    input [31:0] val;
    input [31:0] amount;
    input [2:0] f;
    begin
      x = val; y = amount; shift_func = f;
      #1;
      case (f)
        3'b000: expected = val << amount[4:0];
        3'b001: expected = val >> amount[4:0];
        3'b010: expected = $signed(val) >>> amount[4:0];
        default: expected = 32'h0;
      endcase
      check(shift_out, expected, "shift output");
    end
  endtask

  initial begin
    seed = 131;

    // walk the amount for a positive and a negative value
    for (f = 0; f < 3; f = f + 1)
      for (amt = 0; amt < 32; amt = amt + 1) begin
        try(32'h00000001, amt, f);
        try(32'h80000000, amt, f);
        try(32'hF0F0F0F0, amt, f);
        try(32'h7FFFFFFF, amt, f);
      end

    // upper bits of y must not matter
    try(32'hFFFFFFFF, 32'hFFFFFFE3, 3'b000);
    try(32'hFFFFFFFF, 32'hABCD1203, 3'b001);
    try(32'h80000000, 32'h12340025, 3'b010);   // low 5 bits = 5

    // unused function codes
    for (f = 3; f < 8; f = f + 1)
      try(32'h12345678, 32'd4, f);

    for (i = 0; i < 2000; i = i + 1)
      try($random(seed), $random(seed), $random(seed));

    if (errors == 0) $display("tb_shift_unit: all %0d checks passed", checks);
    else             $display("tb_shift_unit: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
