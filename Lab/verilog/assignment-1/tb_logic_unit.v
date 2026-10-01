`timescale 1ns/1ps

module tb_logic_unit;
  reg [3:0] A, B;
  reg [1:0] sel;
  reg [4:0] expected;
  wire [4:0] Y;

  integer i;
  integer passed, failed;

  logic_unit alu(
    .A(A),
    .B(B),
    .sel(sel),
    .Y(Y)
  );

  initial begin
    $dumpfile("logic_sim.vcd");
    $dumpvars(0, tb_logic_unit);

    passed = 0;
    failed = 0;

    sel = 2'b00;
    for(i = 0; i <= 8'b11111111; i = i + 1) begin
      {A, B} = i;
      expected = A + B;
      #20;
      if (Y == expected) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
      end
    end

    sel = 2'b01;
    for(i = 0; i <= 8'b11111111; i = i + 1) begin
      {A, B} = i;
      expected = A & B;
      #20;
      if (Y == expected) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
      end
    end

    sel = 2'b10;
    for(i = 0; i <= 8'b11111111; i = i + 1) begin
      {A, B} = i;
      expected = A | B;
      #20;
      if (Y == expected) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
      end
    end

    sel = 2'b11;
    for(i = 0; i <= 8'b11111111; i = i + 1) begin
      {A, B} = i;
      expected = A ^ B;
      #20;
      if (Y == expected) begin
        passed = passed + 1;
      end
      else begin
        failed = failed + 1;
      end
    end

    $display("Passed: %d;\tFailed: %d;", passed, failed);

  end
endmodule
