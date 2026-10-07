`timescale 1ns/1ps
module instruction_cache_tb;
  reg         clk = 0, ena = 1, ic_enable = 1;
  reg  [31:0] pc = 0;
  wire [4:0]  rs, rt, rd, shamt;
  wire [15:0] imm;
  wire [25:0] jta;
  wire [5:0]  opcode, fn_sel;

  integer errors = 0, i;
  reg [31:0] instr, last_instr;

  instruction_cache dut (
    .clk(clk), .ena(ena), .ic_enable(ic_enable), .pc(pc),
    .rs(rs), .rt(rt), .rd(rd), .shamt(shamt), .imm(imm), .jta(jta),
    .opcode(opcode), .fn_sel(fn_sel)
  );

  always #5 clk = ~clk;

  // Must match the stub ROM contents in sim_models.v
  function [31:0] rom_word(input integer a);
    rom_word = (a * 32'h9E3779B1) ^ 32'hA5A5A5A5 ^ (a << 7);
  endfunction

  // Field layout exactly as written in instruction_cache.v
  task check_fields(input [31:0] w, input [8*36-1:0] msg);
    begin
      if (opcode !== w[31:26]) begin errors = errors + 1; $display("FAIL %0s: opcode %h exp %h", msg, opcode, w[31:26]); end
      if (rd     !== w[25:21]) begin errors = errors + 1; $display("FAIL %0s: rd %h exp %h",     msg, rd,     w[25:21]); end
      if (rs     !== w[20:16]) begin errors = errors + 1; $display("FAIL %0s: rs %h exp %h",     msg, rs,     w[20:16]); end
      if (rt     !== w[15:11]) begin errors = errors + 1; $display("FAIL %0s: rt %h exp %h",     msg, rt,     w[15:11]); end
      if (shamt  !== w[10:6])  begin errors = errors + 1; $display("FAIL %0s: shamt %h exp %h",  msg, shamt,  w[10:6]);  end
      if (fn_sel !== w[5:0])   begin errors = errors + 1; $display("FAIL %0s: fn_sel %h exp %h", msg, fn_sel, w[5:0]);   end
      if (imm    !== w[15:0])  begin errors = errors + 1; $display("FAIL %0s: imm %h exp %h",    msg, imm,    w[15:0]);  end
      if (jta    !== w[25:0])  begin errors = errors + 1; $display("FAIL %0s: jta %h exp %h",    msg, jta,    w[25:0]);  end
    end
  endtask

  task fetch(input [31:0] addr, input [8*36-1:0] msg);
    begin
      @(negedge clk);
      pc = addr;
      @(posedge clk); #1;
      instr = rom_word(addr[11:2]);
      check_fields(instr, msg);
      last_instr = instr;
    end
  endtask

  initial begin
    // 1. sweep every word address (pc[11:2])
    for (i = 0; i < 1024; i = i + 1)
      fetch({20'h0, i[9:0], 2'b00}, "sweep");

    // 2. pc[1:0] and pc[31:12] must be ignored
    fetch(32'h0000_0003,                 "pc[1:0]=3 ignored");
    fetch(32'hFFFF_F000 | (32'd5 << 2),  "pc[31:12] ignored");
    for (i = 0; i < 300; i = i + 1)
      fetch($urandom, "random pc");

    // 3. ena=0 or ic_enable=0 must not update the output (ROM holds last value)
    fetch(32'h0000_0040, "set up hold test");
    @(negedge clk); ic_enable = 0; pc = 32'h0000_0080;
    @(posedge clk); #1; check_fields(last_instr, "ic_enable=0 holds");
    @(negedge clk); ic_enable = 1; ena = 0; pc = 32'h0000_00C0;
    @(posedge clk); #1; check_fields(last_instr, "ena=0 holds");
    @(negedge clk); ena = 1; pc = 32'h0000_00C0;
    @(posedge clk); #1; check_fields(rom_word(32'h30), "re-enabled fetch");

    if (errors == 0) $display("instruction_cache_tb: PASS");
    else             $display("instruction_cache_tb: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
