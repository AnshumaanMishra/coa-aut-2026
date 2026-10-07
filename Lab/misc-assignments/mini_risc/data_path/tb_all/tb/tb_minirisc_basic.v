`timescale 1ns/1ps
// Top level behavioural testbench for Assignment 1B.
//
// The final control FSM isn't part of 1B, so a small combinational decoder
// (tb_minimal_decoder, bottom of this file) turns opcode/fn from the
// instruction ROM into control signals for the data path. Everything else is
// the real data_path: PC, instruction ROM, register file, immediate
// extension, ALU input mux, ALU and write-back.
//
// `reset` plays the role of the IDLE state of the FSM: it forces next_pc to
// 0 so that instruction 0 is already in the ROM output when reset goes low.
//
// Run, then open minirisc_basic.vcd. Signals worth adding to the waveform
// are the ones declared under "signals for the waveform" below.

module tb_minirisc_basic;
  reg clk;
  reg reset;

  // control lines from the decoder
  wire pc_enable, ic_enable, hi_lo_enable, reg_write, force_rs_zero;
  wire alu_src, is_branch, mem_read, mem_write;
  wire [2:0] rt_sel, br_type;
  wire [1:0] reg_dst, pc_src, reg_in_src;
  wire [5:0] alu_func;
  wire [5:0] opcode, fn_sel;

  data_path dut (
    .clk(clk), .pc_enable(pc_enable), .ic_enable(ic_enable),
    .hi_lo_enable(hi_lo_enable), .reg_write(reg_write),
    .force_rs_zero(force_rs_zero), .rt_sel(rt_sel), .reg_dst(reg_dst),
    .alu_src(alu_src), .alu_func(alu_func), .pc_src(pc_src),
    .br_type(br_type), .is_branch(is_branch), .mem_read(mem_read),
    .mem_write(mem_write), .reg_in_src(reg_in_src),
    .opcode(opcode), .fn_sel(fn_sel));

  tb_minimal_decoder dec (
    .reset(reset), .opcode(opcode), .fn_sel(fn_sel),
    .pc_enable(pc_enable), .ic_enable(ic_enable), .hi_lo_enable(hi_lo_enable),
    .reg_write(reg_write), .force_rs_zero(force_rs_zero), .alu_src(alu_src),
    .is_branch(is_branch), .mem_read(mem_read), .mem_write(mem_write),
    .rt_sel(rt_sel), .br_type(br_type), .reg_dst(reg_dst), .pc_src(pc_src),
    .reg_in_src(reg_in_src), .alu_func(alu_func));

  // signals for the waveform
  wire [31:0] pc          = dut.pc_out;
  wire [31:0] instruction = {opcode, dut.rd, dut.rs, dut.imm};
  wire [4:0]  rs_addr     = dut.rs_addr;
  wire [4:0]  rt_addr     = dut.rt_addr;
  wire [31:0] rs_data     = dut.rs_out;
  wire [31:0] rt_data     = dut.rt_out;
  wire [31:0] imm_value   = dut.imm_ext;
  wire [31:0] alu_a       = dut.rs_out;
  wire [31:0] alu_b       = dut.alu_src_rt_in;
  wire [31:0] alu_result  = dut.alu_out_lo;
  wire [4:0]  dest_addr   = dut.rd_in;
  wire [31:0] wb_data     = dut.reg_in_lo;

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

  // ---- program ----
  localparam [5:0]
    F_SLT = 6'b001000, F_SGT = 6'b001001,
    F_ADD = 6'b010000, F_SUB = 6'b010001,
    F_AND = 6'b011000, F_XOR = 6'b011100,
    F_SLL = 6'b100000, F_SRA = 6'b100010;
  localparam [5:0]
    OP_R = 6'b100000, OP_ADDI = 6'b110000, OP_SUBI = 6'b110001,
    OP_ORI = 6'b110011, OP_HALT = 6'b111111;

  function [31:0] enc_r;
    input [5:0] fn;
    input [4:0] rd, rs, rt;
    enc_r = {OP_R, rd, rs, rt, 5'b0, fn};
  endfunction

  function [31:0] enc_i;
    input [5:0] op;
    input [4:0] rd, rs;
    input [15:0] imm;
    enc_i = {op, rd, rs, imm};
  endfunction

  // what each instruction should look like at the ALU: operand A, operand B,
  // result and destination register
  reg [31:0] exp_a   [0:14];
  reg [31:0] exp_b   [0:14];
  reg [31:0] exp_res [0:14];
  reg [4:0]  exp_rd  [0:14];
  reg [31:0] final_regs [0:15];

  integer k;

  task expect_line;
    input integer n;
    input [31:0] a, b, res;
    input [4:0] rd;
    begin
      exp_a[n] = a; exp_b[n] = b; exp_res[n] = res; exp_rd[n] = rd;
    end
  endtask

  task load_program;
    begin
      for (k = 0; k < 1024; k = k + 1) dut.ic.rom.mem[k] = 32'h0;

      dut.ic.rom.mem[0]  = enc_i(OP_ADDI, 1, 0, 16'd5);       // ADDI R1, R0, 5
      dut.ic.rom.mem[1]  = enc_i(OP_ADDI, 2, 0, 16'd7);       // ADDI R2, R0, 7
      dut.ic.rom.mem[2]  = enc_r(F_ADD, 3, 1, 2);             // ADD  R3, R1, R2
      dut.ic.rom.mem[3]  = enc_r(F_SUB, 4, 2, 1);             // SUB  R4, R2, R1
      dut.ic.rom.mem[4]  = enc_r(F_AND, 5, 1, 2);             // AND  R5, R1, R2
      dut.ic.rom.mem[5]  = enc_r(F_XOR, 6, 1, 2);             // XOR  R6, R1, R2
      dut.ic.rom.mem[6]  = enc_r(F_SLL, 7, 3, 4);             // SLL  R7, R3, R4
      dut.ic.rom.mem[7]  = enc_i(OP_ADDI, 8, 0, 16'hFFFD);    // ADDI R8, R0, -3
      dut.ic.rom.mem[8]  = enc_r(F_SLT, 9, 8, 1);             // SLT  R9, R8, R1
      dut.ic.rom.mem[9]  = enc_r(F_SGT, 10, 1, 8);            // SGT  R10, R1, R8
      dut.ic.rom.mem[10] = enc_i(OP_ADDI, 0, 1, 16'd100);     // ADDI R0, R1, 100  (write to R0)
      dut.ic.rom.mem[11] = enc_r(F_ADD, 11, 0, 3);            // ADD  R11, R0, R3
      dut.ic.rom.mem[12] = enc_r(F_SRA, 12, 8, 4);            // SRA  R12, R8, R4
      dut.ic.rom.mem[13] = enc_i(OP_SUBI, 13, 3, 16'd2);      // SUBI R13, R3, 2
      dut.ic.rom.mem[14] = enc_i(OP_ORI, 14, 1, 16'h8000);    // ORI  R14, R1, 0x8000
      dut.ic.rom.mem[15] = {OP_HALT, 26'b0};                  // HALT

      //          n   A           B           result      rd
      expect_line( 0, 32'h0,      32'd5,      32'd5,      1);
      expect_line( 1, 32'h0,      32'd7,      32'd7,      2);
      expect_line( 2, 32'd5,      32'd7,      32'd12,     3);
      expect_line( 3, 32'd7,      32'd5,      32'd2,      4);
      expect_line( 4, 32'd5,      32'd7,      32'd5,      5);
      expect_line( 5, 32'd5,      32'd7,      32'd2,      6);
      expect_line( 6, 32'd12,     32'd2,      32'd48,     7);
      expect_line( 7, 32'h0,      32'hFFFFFFFD, 32'hFFFFFFFD, 8);
      expect_line( 8, 32'hFFFFFFFD, 32'd5,    32'd1,      9);
      expect_line( 9, 32'd5,      32'hFFFFFFFD, 32'd1,    10);
      expect_line(10, 32'd5,      32'd100,    32'd105,    0);
      expect_line(11, 32'h0,      32'd12,     32'd12,     11);
      expect_line(12, 32'hFFFFFFFD, 32'd2,    32'hFFFFFFFF, 12);
      expect_line(13, 32'd12,     32'd2,      32'd10,     13);
      expect_line(14, 32'd5,      32'h8000,   32'h8005,   14);

      final_regs[0]  = 32'h0;
      final_regs[1]  = 32'd5;
      final_regs[2]  = 32'd7;
      final_regs[3]  = 32'd12;
      final_regs[4]  = 32'd2;
      final_regs[5]  = 32'd5;
      final_regs[6]  = 32'd2;
      final_regs[7]  = 32'd48;
      final_regs[8]  = 32'hFFFFFFFD;
      final_regs[9]  = 32'd1;
      final_regs[10] = 32'd1;
      final_regs[11] = 32'd12;
      final_regs[12] = 32'hFFFFFFFF;
      final_regs[13] = 32'd10;
      final_regs[14] = 32'h8005;
      final_regs[15] = 32'h0;
    end
  endtask

  function [47:0] mnemonic;
    input [5:0] op;
    input [5:0] fn;
    begin
      case (op)
        6'b100000: case (fn)
                     F_ADD: mnemonic = "ADD";
                     F_SUB: mnemonic = "SUB";
                     F_AND: mnemonic = "AND";
                     F_XOR: mnemonic = "XOR";
                     F_SLL: mnemonic = "SLL";
                     F_SRA: mnemonic = "SRA";
                     F_SLT: mnemonic = "SLT";
                     F_SGT: mnemonic = "SGT";
                     default: mnemonic = "R-type";
                   endcase
        OP_ADDI: mnemonic = "ADDI";
        OP_SUBI: mnemonic = "SUBI";
        OP_ORI:  mnemonic = "ORI";
        OP_HALT: mnemonic = "HALT";
        6'b000000: mnemonic = "NOP";
        default: mnemonic = "?";
      endcase
    end
  endfunction

  // ---- per cycle monitor ----
  // sampled 4 ns after each falling edge, i.e. 1 ns before the next rising
  // edge, when everything has settled and the current instruction is still
  // being executed
  integer idx;
  reg running;
  reg halted;

  initial begin
    running = 0;
    halted = 0;
    $display(" time    pc   instr     op      rs  rt  rd | A         B         result    | we wb");
  end

  always @(negedge clk) begin
    #4;
    if (running && !halted) begin
      idx = pc >> 2;

      $display("%8t  %4h  %h  %-6s  R%0d  R%0d  R%0d | %h  %h  %h  |  %b  %h",
               $time, pc, instruction, mnemonic(opcode, fn_sel),
               rs_addr, rt_addr, dest_addr, alu_a, alu_b, alu_result,
               reg_write, wb_data);

      // fetch: the word coming out of the ROM must be the one at this pc
      check(instruction, dut.ic.rom.mem[idx], "fetched word matches ROM");

      if (opcode == OP_HALT) begin
        halted = 1;
      end else begin
        check(alu_a, exp_a[idx], "ALU operand A");
        check(alu_b, exp_b[idx], "ALU operand B");
        check(alu_result, exp_res[idx], "ALU result");
        check(dest_addr, exp_rd[idx], "destination register");
        check(reg_write, 1'b1, "register write enable");
      end
    end
  end

  // ---- main sequence ----
  initial begin
    $timeformat(-9, 0, " ns", 8);
    $dumpfile("minirisc_basic.vcd");
    $dumpvars(0, tb_minirisc_basic);

    reset = 1;
    #1;
    load_program;

    // hold reset for a few clocks, then release between edges
    repeat (3) @(posedge clk);
    check(pc, 32'h0, "pc is 0 during reset");
    check(instruction, dut.ic.rom.mem[0], "instruction 0 ready when reset ends");
    @(negedge clk);
    reset = 0;
    running = 1;

    // wait for HALT to show up at the ROM output, then let it sit a few cycles
    wait (halted);
    repeat (3) @(posedge clk);
    #1;

    // pc stops on HALT
    check(pc, 32'd15 * 4, "pc stays on HALT");

    // register file contents after the whole program
    for (k = 0; k < 16; k = k + 1)
      check(dut.rf.registers[k], final_regs[k], "final register value");

    // R0 specifically, after the ADDI R0, R1, 100
    check(dut.rf.registers[0], 32'h0, "R0 still zero");

    if (errors == 0) $display("tb_minirisc_basic: all %0d checks passed", checks);
    else             $display("tb_minirisc_basic: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end

  // don't hang if something is wrong with the fetch sequencing
  initial begin
    #5000;
    $display("tb_minirisc_basic: timeout, HALT was never reached");
    $finish;
  end
endmodule


// Minimal decoder for the 1B demonstration: only what the test program needs
// plus the other single-cycle ALU instructions. Loads, stores, branches,
// jumps and the multiplier are left to the full control path.
module tb_minimal_decoder (
  input reset,
  input [5:0] opcode,
  input [5:0] fn_sel,
  output reg pc_enable, ic_enable, hi_lo_enable, reg_write, force_rs_zero,
  output reg alu_src, is_branch, mem_read, mem_write,
  output reg [2:0] rt_sel, br_type,
  output reg [1:0] reg_dst, pc_src, reg_in_src,
  output reg [5:0] alu_func
);
  always @(*) begin
    // quiet defaults: behaves like a NOP that advances the pc
    pc_enable = 1; ic_enable = 1; hi_lo_enable = 0; reg_write = 0;
    force_rs_zero = 0; alu_src = 0; is_branch = 0; mem_read = 0; mem_write = 0;
    rt_sel = 3'b000; br_type = 3'b000;
    reg_dst = 2'b01;        // rd field
    pc_src = 2'b00;         // pc + 1
    reg_in_src = 2'b01;     // ALU result
    alu_func = 6'b010000;   // add

    if (reset) begin
      pc_src = 2'b11;       // force next_pc to 0
    end else begin
      case (opcode)
        6'b000000: ;                                  // NOP

        6'b100000: begin                              // R-type, fn field is the ALU code
          alu_func = fn_sel;
          // MUL / MULU are deferred past 1B
          reg_write = !(fn_sel == 6'b010010 || fn_sel == 6'b010011);
        end

        6'b100010: begin                              // LI: 0 + imm
          reg_write = 1; alu_src = 1; force_rs_zero = 1;
        end
        6'b100011: begin                              // LUI
          reg_write = 1; alu_src = 1; alu_func = 6'b000000;
        end
        6'b100100: begin                              // MOVE: rs + 0
          reg_write = 1; rt_sel = 3'b010;
        end

        // I-type ALU group, each opcode maps to the matching ALU code
        6'b110000: begin reg_write = 1; alu_src = 1; alu_func = 6'b010000; end  // ADDI
        6'b110001: begin reg_write = 1; alu_src = 1; alu_func = 6'b010001; end  // SUBI
        6'b110010: begin reg_write = 1; alu_src = 1; alu_func = 6'b011000; end  // ANDI
        6'b110011: begin reg_write = 1; alu_src = 1; alu_func = 6'b011001; end  // ORI
        6'b110100: begin reg_write = 1; alu_src = 1; alu_func = 6'b011011; end  // NORI
        6'b110101: begin reg_write = 1; alu_src = 1; alu_func = 6'b011100; end  // XORI
        6'b110110: begin reg_write = 1; alu_src = 1; alu_func = 6'b100000; end  // SLLI
        6'b110111: begin reg_write = 1; alu_src = 1; alu_func = 6'b100001; end  // SRLI
        6'b111000: begin reg_write = 1; alu_src = 1; alu_func = 6'b100010; end  // SRAI
        6'b111001: begin reg_write = 1; alu_src = 1; alu_func = 6'b001000; end  // SLTI
        6'b111010: begin reg_write = 1; alu_src = 1; alu_func = 6'b001001; end  // SGTI
        6'b111011: begin reg_write = 1; alu_src = 1; alu_func = 6'b001010; end  // SLEI
        6'b111100: begin reg_write = 1; alu_src = 1; alu_func = 6'b001011; end  // SGEI
        6'b111101: begin reg_write = 1; alu_src = 1; alu_func = 6'b001100; end  // SEQI
        6'b111110: begin reg_write = 1; alu_src = 1; alu_func = 6'b001101; end  // SNEI

        6'b111111: begin                              // HALT: freeze pc and instruction
          pc_enable = 0; ic_enable = 0;
        end

        default: ;                                    // everything else is not part of 1B
      endcase
    end
  end
endmodule
