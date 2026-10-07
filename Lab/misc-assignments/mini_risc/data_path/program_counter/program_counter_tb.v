`timescale 1ns/1ps
module program_counter_tb;
  reg         clk = 0;
  reg  [31:0] next_pc = 0;
  reg         pc_write_en = 0;
  wire [31:0] pc_out;

  reg [31:0] model;
  integer errors = 0;
  integer i;

  program_counter dut (.clk(clk), .next_pc(next_pc), .pc_write_en(pc_write_en), .pc_out(pc_out));

  always #5 clk = ~clk;

  task check(input [31:0] exp, input [8*32-1:0] msg);
    begin
      if (pc_out !== exp) begin
        errors = errors + 1;
        $display("FAIL [%0t] %0s: pc_out=%h expected=%h", $time, msg, pc_out, exp);
      end
    end
  endtask

  // apply inputs on the falling edge, sample just after the rising edge
  task step(input en, input [31:0] npc);
    begin
      @(negedge clk);
      pc_write_en = en;
      next_pc     = npc;
      @(posedge clk);
      #1;
    end
  endtask

  initial begin
    #1; check(32'h0, "initial value is 0");

    step(1, 32'h0000_0004); check(32'h0000_0004, "load 4");
    step(0, 32'h0000_0008); check(32'h0000_0004, "hold when disabled");
    step(1, 32'hFFFF_FFFC); check(32'hFFFF_FFFC, "load max aligned");
    step(1, 32'h0000_0000); check(32'h0000_0000, "load zero");

    // pc_out must only change on the clock edge
    step(1, 32'h1234_5678);
    check(32'h1234_5678, "pre-glitch");
    #2 next_pc = 32'hDEAD_BEEF;
    #1 check(32'h1234_5678, "next_pc change between edges ignored");

    // pc_write_en dropped before the edge must not load
    @(negedge clk); pc_write_en = 1; next_pc = 32'hCAFE_0000;
    #1 pc_write_en = 0;
    @(posedge clk); #1;
    check(32'h1234_5678, "enable dropped before edge: hold");

    // randomized against a model
    model = pc_out;
    for (i = 0; i < 500; i = i + 1) begin
      @(negedge clk);
      pc_write_en = $urandom_range(0, 1);
      next_pc     = $urandom;
      @(posedge clk);
      if (pc_write_en) model = next_pc;
      #1;
      check(model, "random");
    end

    if (errors == 0) $display("program_counter_tb: PASS");
    else             $display("program_counter_tb: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
