`timescale 1ns/1ps
module tb_sign_extender;
  reg  [15:0] imm;
  wire [31:0] se32;
  wire [29:0] se30;   // next_address_decoder uses the 30 bit flavour

  sign_extender #(.WIDTH(32)) dut32 (.imm_in(imm), .se_imm(se32));
  sign_extender #(.WIDTH(30)) dut30 (.imm_in(imm), .se_imm(se30));

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

  task try;
    input [15:0] v;
    reg [31:0] e32;
    begin
      imm = v; #1;
      e32 = v[15] ? {16'hFFFF, v} : {16'h0000, v};
      check(se32, e32, "32 bit extend");
      check(se30, e32[29:0], "30 bit extend");
    end
  endtask

  initial begin
    seed = 5;
    try(16'h0000);
    try(16'h0001);
    try(16'h7FFF);   // biggest positive
    try(16'h8000);   // smallest negative
    try(16'hFFFF);   // -1
    try(16'hFFFE);
    try(16'h1234);
    try(16'hABCD);

    for (i = 0; i < 1000; i = i + 1)
      try($random(seed));

    if (errors == 0) $display("tb_sign_extender: all %0d checks passed", checks);
    else             $display("tb_sign_extender: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
