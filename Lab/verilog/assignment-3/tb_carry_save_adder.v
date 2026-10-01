`timescale 1ns/1ps

module tb_carry_save_adder;
  reg [3:0] A, B, C;
  wire [5:0] O;
  reg [5:0] expected;

  integer i;
  integer passed, failed;

  carry_save_adder_3x4 csa(
    .A(A),
    .B(B),
    .C(C),
    .O(O)
  );

  initial begin
    $dumpfile("csa.vcd");
    $dumpvars(0, tb_carry_save_adder);
    passed = 0;
    failed = 0;

    for(i = 0; i < 4096; i = i + 1) begin
      {A, B, C} = i;
      expected = {2'b00, A} + {2'b00, B} + {2'b00, C};
      #20;
      if(O == expected) begin
        passed = passed + 1;
      end
      else begin
        failed++;
      end
    end
    $display("Passed: %d\nFailed: %d", passed, failed);
    $finish;
  end
endmodule
