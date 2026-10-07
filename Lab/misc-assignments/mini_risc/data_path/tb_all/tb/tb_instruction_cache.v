`timescale 1ns/1ps
module tb_instruction_cache;
  reg         clk, ena, ic_enable;
  reg  [31:0] pc;
  wire [4:0]  rs, rt, rd, shamt;
  wire [15:0] imm;
  wire [25:0] jta;
  wire [5:0]  opcode, fn_sel;

  instruction_cache dut (
    .clk(clk), .ena(ena), .ic_enable(ic_enable), .pc(pc),
    .rs(rs), .rt(rt), .rd(rd), .shamt(shamt), .imm(imm), .jta(jta),
    .opcode(opcode), .fn_sel(fn_sel));

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
  integer i;

  // fetch the word at byte address a
  task fetch;
    input [31:0] a;
    begin
      pc = a; ena = 1; ic_enable = 1;
      @(posedge clk); #1;
    end
  endtask

  initial begin
    pc = 0; ena = 1; ic_enable = 1;

    // put some known instructions straight into the ROM array
    // (examples from the encoding table in the report)
    dut.rom.mem[0] = 32'hC0200005;   // ADDI R1, R0, 5
    dut.rom.mem[1] = 32'h80611010;   // ADD  R3, R1, R2
    dut.rom.mem[2] = 32'h94850008;   // LD   R4, 8(R5)
    dut.rom.mem[3] = 32'h98C7FFFC;   // ST   R6, -4(R7)
    dut.rom.mem[4] = 32'h40410003;   // BEQ  R1, R2, +3
    dut.rom.mem[5] = 32'hA0000010;   // J    0x10
    dut.rom.mem[6] = 32'hFC000000;   // HALT
    dut.rom.mem[7] = 32'h8C201234;   // LUI  R1, 0x1234
    dut.rom.mem[8] = 32'h80021813;   // MULU R2, R3
    dut.rom.mem[9] = 32'hDEBEB6EF;   // opcode 110111, rd 10101, rs 11110, rt 10110, shamt 11011, fn 101111
    @(posedge clk); #1;

    fetch(32'd0);
    check(opcode, 6'b110000, "ADDI opcode");
    check(rd, 5'd1, "ADDI rd");
    check(rs, 5'd0, "ADDI rs");
    check(imm, 16'h0005, "ADDI imm");

    fetch(32'd4);
    check(opcode, 6'b100000, "ADD opcode");
    check(rd, 5'd3, "ADD rd");
    check(rs, 5'd1, "ADD rs");
    check(rt, 5'd2, "ADD rt");
    check(shamt, 5'd0, "ADD shamt");
    check(fn_sel, 6'b010000, "ADD fn");

    fetch(32'd8);
    check(opcode, 6'b100101, "LD opcode");
    check(rd, 5'd4, "LD rd");
    check(rs, 5'd5, "LD rs");
    check(imm, 16'h0008, "LD imm");

    fetch(32'd12);
    check(opcode, 6'b100110, "ST opcode");
    check(rd, 5'd6, "ST rd");
    check(rs, 5'd7, "ST rs");
    check(imm, 16'hFFFC, "ST imm");

    fetch(32'd16);
    check(opcode, 6'b010000, "BEQ opcode");
    check(rd, 5'd2, "BEQ rs2 field");
    check(rs, 5'd1, "BEQ rs");
    check(imm, 16'h0003, "BEQ offset");

    fetch(32'd20);
    check(opcode, 6'b101000, "J opcode");
    check(jta, 26'h0000010, "J target");

    fetch(32'd24);
    check(opcode, 6'b111111, "HALT opcode");

    fetch(32'd28);
    check(opcode, 6'b100011, "LUI opcode");
    check(imm, 16'h1234, "LUI imm");

    fetch(32'd32);
    check(opcode, 6'b100000, "MULU opcode");
    check(rs, 5'd2, "MULU rs");
    check(rt, 5'd3, "MULU rt");
    check(fn_sel, 6'b010011, "MULU fn");

    // all the fields at once on an irregular word
    fetch(32'd36);
    check(opcode, 6'b110111, "field split: opcode");
    check(rd, 5'b10101, "field split: rd");
    check(rs, 5'b11110, "field split: rs");
    check(rt, 5'b10110, "field split: rt");
    check(shamt, 5'b11011, "field split: shamt");
    check(fn_sel, 6'b101111, "field split: fn");

    // pc bits [1:0] are ignored and the ROM index is pc[11:2]
    fetch(32'd6);
    check(opcode, 6'b100000, "unaligned pc reads word 1");
    check(fn_sel, 6'b010000, "unaligned pc fn");
    fetch(32'h00001000);
    check(opcode, 6'b110000, "pc 0x1000 aliases word 0");

    // ic_enable low: output must stay on the current instruction
    fetch(32'd0);
    pc = 32'd24; ic_enable = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(opcode, 6'b110000, "ic_enable=0 holds opcode");
    check(imm, 16'h0005, "ic_enable=0 holds imm");

    // and picks up again once enabled
    ic_enable = 1;
    @(posedge clk); #1;
    check(opcode, 6'b111111, "resumes after ic_enable=1");

    // ena low also freezes the output
    pc = 32'd0; ena = 0;
    @(posedge clk); #1;
    check(opcode, 6'b111111, "ena=0 holds opcode");

    if (errors == 0) $display("tb_instruction_cache: all %0d checks passed", checks);
    else             $display("tb_instruction_cache: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
