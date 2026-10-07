`timescale 1ns/1ps
module tb_program_counter;
  reg         clk, pc_write_en;
  reg  [31:0] next_pc;
  wire [31:0] pc_out;

  program_counter dut (.clk(clk), .next_pc(next_pc), .pc_write_en(pc_write_en), .pc_out(pc_out));

  initial clk = 0;
  always #5 clk = ~clk;

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
  reg [31:0] model;

  initial begin
    seed = 171;
    pc_write_en = 0;
    next_pc = 32'h00000000;

    // comes up at zero without any clock edge
    #1;
    check(pc_out, 32'h0, "reset value");

    // enable low: value must be ignored
    next_pc = 32'h00000040;
    @(posedge clk); #1;
    check(pc_out, 32'h0, "held while disabled");

    // enable high: loads on the edge
    pc_write_en = 1;
    @(posedge clk); #1;
    check(pc_out, 32'h40, "loads next_pc");

    // changing next_pc between edges has no effect until the next edge
    next_pc = 32'h00000080;
    #2;
    check(pc_out, 32'h40, "not combinational");
    @(posedge clk); #1;
    check(pc_out, 32'h80, "picks up new value on edge");

    // disable again, then change input
    pc_write_en = 0;
    next_pc = 32'hFFFFFFFC;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(pc_out, 32'h80, "holds over several cycles");

    // large address
    pc_write_en = 1;
    @(posedge clk); #1;
    check(pc_out, 32'hFFFFFFFC, "top of address space");

    // random enable pattern against a simple model
    model = pc_out;
    for (i = 0; i < 500; i = i + 1) begin
      next_pc = $random(seed);
      pc_write_en = $random(seed);
      if (pc_write_en) model = next_pc;
      @(posedge clk); #1;
      check(pc_out, model, "random sequence");
    end

    if (errors == 0) $display("tb_program_counter: all %0d checks passed", checks);
    else             $display("tb_program_counter: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
