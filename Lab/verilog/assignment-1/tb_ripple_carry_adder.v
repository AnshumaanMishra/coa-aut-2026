`timescale 1ns/1ps

module tb_ripple_carry_adder;
  reg [3:0] a, b;
  wire [4:0] s;

  integer i, j;
  integer passed, failed;

  ripple_carry_adder_4bit rca(
    .A(a),
    .B(b),
    .S(s)
  );

  initial begin
    $dumpfile("ripple_carry.vcd");
    $dumpvars(0, tb_ripple_carry_adder);
    passed = 0;
    failed = 0;
    for(i = 0; i <= 8'b11111111; i = i + 1) begin
      {a, b} = i; #10;
      if(a + b == s) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
      end
    end

    $display("Passed: %d;\tFailed: %d;", passed, failed);
  end
endmodule
