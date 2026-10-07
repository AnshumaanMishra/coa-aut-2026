`timescale 1ns/1ps
// There is no control unit here, so this bench plays the part of the control
// path: it loads a small program into the ROM and then sets the control word
// for each instruction by hand (see Appendix A of the report), one clock per
// instruction (two for LD).
module tb_data_path;
  reg clk;
  reg pc_enable, ic_enable, hi_lo_enable, reg_write, force_rs_zero;
  reg alu_src, is_branch, mem_read, mem_write;
  reg [2:0] rt_sel, br_type;
  reg [1:0] reg_dst, pc_src, reg_in_src;
  reg [5:0] alu_func;
  wire [5:0] opcode, fn_sel;

  data_path dut (
    .clk(clk), .pc_enable(pc_enable), .ic_enable(ic_enable),
    .hi_lo_enable(hi_lo_enable), .reg_write(reg_write),
    .force_rs_zero(force_rs_zero), .rt_sel(rt_sel), .reg_dst(reg_dst),
    .alu_src(alu_src), .alu_func(alu_func), .pc_src(pc_src),
    .br_type(br_type), .is_branch(is_branch), .mem_read(mem_read),
    .mem_write(mem_write), .reg_in_src(reg_in_src),
    .opcode(opcode), .fn_sel(fn_sel));

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
  // ALU function codes
  localparam [5:0]
    F_LUI = 6'b000000, F_SLT = 6'b001000, F_SGT = 6'b001001,
    F_ADD = 6'b010000, F_SUB = 6'b010001, F_MUL = 6'b010010, F_MULU = 6'b010011,
    F_OR  = 6'b011001, F_SRA = 6'b100010;

  // opcodes
  localparam [5:0]
    OP_R = 6'b100000, OP_LI = 6'b100010, OP_LUI = 6'b100011, OP_LD = 6'b100101,
    OP_ST = 6'b100110, OP_J = 6'b101000, OP_JAL = 6'b101001, OP_JR = 6'b101011,
    OP_ADDI = 6'b110000, OP_ORI = 6'b110011, OP_SRAI = 6'b111000,
    OP_SGTI = 6'b111010,
    OP_BEQ = 6'b010000, OP_BZ = 6'b010001, OP_BNE = 6'b010010,
    OP_BLT = 6'b010011, OP_BV = 6'b010111,
    OP_NOP = 6'b000000, OP_HALT = 6'b111111;

  // instruction builders
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

  // branch format: op, rs2 (25:21), rs (20:16), offset
  function [31:0] enc_b;
    input [5:0] op;
    input [4:0] rs2, rs;
    input [15:0] off;
    enc_b = {op, rs2, rs, off};
  endfunction

  function [31:0] enc_j;
    input [5:0] op;
    input [25:0] target;
    enc_j = {op, target};
  endfunction

  initial clk = 0;

  task tick;
    begin
      #5 clk = 1;
      #5 clk = 0;
    end
  endtask

  // all control lines to a quiet state (acts like a NOP that still advances pc)
  task idle_word;
    begin
      pc_enable = 1; ic_enable = 1; hi_lo_enable = 0; reg_write = 0;
      force_rs_zero = 0; alu_src = 0; is_branch = 0; mem_read = 0; mem_write = 0;
      rt_sel = 3'b000; br_type = 3'b000; reg_dst = 2'b01; pc_src = 2'b00;
      reg_in_src = 2'b01; alu_func = F_ADD;
    end
  endtask

  task do_nop;
    begin idle_word; tick; end
  endtask

  task do_rtype;
    input [5:0] fn;
    begin
      idle_word;
      reg_write = 1; alu_func = fn;
      tick;
    end
  endtask

  task do_itype;
    input [5:0] fn;
    begin
      idle_word;
      reg_write = 1; alu_src = 1; alu_func = fn;
      tick;
    end
  endtask

  task do_ld;
    begin
      // first cycle: address goes out, pc and instruction are frozen
      idle_word;
      pc_enable = 0; ic_enable = 0; mem_read = 1; alu_src = 1; alu_func = F_ADD;
      reg_in_src = 2'b00;
      tick;
      // second cycle: data is there, write it and move on
      idle_word;
      alu_src = 1; alu_func = F_ADD; reg_in_src = 2'b00; reg_write = 1;
      tick;
    end
  endtask

  task do_st;
    begin
      idle_word;
      alu_src = 1; alu_func = F_ADD; rt_sel = 3'b001; mem_write = 1;
      tick;
    end
  endtask

  task do_mulu;
    begin
      idle_word;
      reg_dst = 2'b10; hi_lo_enable = 1; reg_write = 1; alu_func = F_MULU;
      tick;
    end
  endtask

  // MFHI / MFLO: 0 + HI (or LO) through the rt port
  task do_mfhl;
    input [2:0] sel;
    begin
      idle_word;
      reg_write = 1; force_rs_zero = 1; rt_sel = sel; alu_func = F_ADD;
      tick;
    end
  endtask

  task do_branch;
    input [2:0] bt;
    input [2:0] rtsel;
    begin
      idle_word;
      alu_func = F_SUB; is_branch = 1; br_type = bt; rt_sel = rtsel;
      tick;
    end
  endtask

  task do_jump;
    begin idle_word; pc_src = 2'b01; tick; end
  endtask

  task do_jal;
    begin
      idle_word;
      reg_dst = 2'b11; reg_write = 1; reg_in_src = 2'b10; pc_src = 2'b01;
      tick;
    end
  endtask

  task do_jr;
    begin idle_word; pc_src = 2'b10; tick; end
  endtask

  task check_reg;
    input [4:0] n;
    input [31:0] expected;
    input [255:0] what;
    begin
      check(dut.rf.registers[n], expected, what);
    end
  endtask

  task check_pc;
    input integer word;
    input [255:0] what;
    begin
      check(dut.pc.pc_out, word * 4, what);
    end
  endtask

  integer k;

  initial begin
    // clear the ROM so unused words are NOPs
    for (k = 0; k < 1024; k = k + 1) dut.ic.rom.mem[k] = 32'h0;

    // the program, word index in the comment
    dut.ic.rom.mem[0]  = enc_i(OP_ADDI, 1, 0, 16'd5);        // 0  ADDI R1, R0, 5
    dut.ic.rom.mem[1]  = enc_i(OP_ADDI, 2, 0, 16'd7);        // 1  ADDI R2, R0, 7
    dut.ic.rom.mem[2]  = enc_r(F_ADD, 3, 1, 2);              // 2  ADD  R3, R1, R2
    dut.ic.rom.mem[3]  = enc_r(F_SUB, 4, 2, 1);              // 3  SUB  R4, R2, R1
    dut.ic.rom.mem[4]  = enc_i(OP_ADDI, 5, 0, 16'hFFFD);     // 4  ADDI R5, R0, -3
    dut.ic.rom.mem[5]  = enc_r(F_SLT, 6, 5, 1);              // 5  SLT  R6, R5, R1
    dut.ic.rom.mem[6]  = enc_i(OP_SGTI, 7, 1, 16'd3);        // 6  SGTI R7, R1, 3
    dut.ic.rom.mem[7]  = enc_i(OP_SRAI, 8, 5, 16'd1);        // 7  SRAI R8, R5, 1
    dut.ic.rom.mem[8]  = enc_i(OP_LUI, 9, 0, 16'h1234);      // 8  LUI  R9, 0x1234
    dut.ic.rom.mem[9]  = enc_i(OP_ORI, 9, 9, 16'h8765);      // 9  ORI  R9, R9, 0x8765
    dut.ic.rom.mem[10] = enc_i(OP_ST, 9, 0, 16'd8);          // 10 ST   R9, 8(R0)
    dut.ic.rom.mem[11] = enc_i(OP_LD, 10, 0, 16'd8);         // 11 LD   R10, 8(R0)
    dut.ic.rom.mem[12] = enc_r(F_MUL, 11, 2, 5);             // 12 MUL  R11, R2, R5
    dut.ic.rom.mem[13] = enc_r(F_MULU, 0, 1, 5);             // 13 MULU R1, R5
    dut.ic.rom.mem[14] = {6'b100001, 5'd12, 21'b0};          // 14 MFHI R12
    dut.ic.rom.mem[15] = {6'b100111, 5'd13, 21'b0};          // 15 MFLO R13
    dut.ic.rom.mem[16] = enc_b(OP_BEQ, 1, 1, 16'd1);         // 16 BEQ  R1, R1, +1  (taken)
    dut.ic.rom.mem[17] = enc_i(OP_ADDI, 14, 0, 16'd99);      // 17 skipped
    dut.ic.rom.mem[18] = enc_b(OP_BNE, 1, 1, 16'd1);         // 18 BNE  R1, R1, +1  (not taken)
    dut.ic.rom.mem[19] = enc_i(OP_ADDI, 14, 0, 16'd1);       // 19 ADDI R14, R0, 1
    dut.ic.rom.mem[20] = enc_b(OP_BLT, 1, 5, 16'd1);         // 20 BLT  R5, R1, +1  (-3 < 5, taken)
    dut.ic.rom.mem[21] = enc_i(OP_ADDI, 14, 0, 16'd99);      // 21 skipped
    dut.ic.rom.mem[22] = enc_b(OP_BZ, 0, 1, 16'd1);          // 22 BZ   R1, +1      (R1 = 5, not taken)
    dut.ic.rom.mem[23] = enc_i(OP_ADDI, 14, 14, 16'd10);     // 23 ADDI R14, R14, 10
    dut.ic.rom.mem[24] = enc_b(OP_BZ, 0, 0, 16'd1);          // 24 BZ   R0, +1      (taken)
    dut.ic.rom.mem[25] = enc_i(OP_ADDI, 14, 0, 16'd99);      // 25 skipped
    dut.ic.rom.mem[26] = enc_i(OP_LUI, 6, 0, 16'h8000);      // 26 LUI  R6, 0x8000
    dut.ic.rom.mem[27] = enc_b(OP_BV, 1, 6, 16'd1);          // 27 BV   R6, R1, +1  (MIN - 5 overflows)
    dut.ic.rom.mem[28] = enc_i(OP_ADDI, 14, 0, 16'd99);      // 28 skipped
    dut.ic.rom.mem[29] = enc_j(OP_JAL, 26'd31);              // 29 JAL  31
    dut.ic.rom.mem[30] = enc_i(OP_ADDI, 12, 0, 16'd99);      // 30 skipped
    dut.ic.rom.mem[31] = enc_j(OP_J, 26'd33);                // 31 J    33
    dut.ic.rom.mem[32] = enc_i(OP_ADDI, 12, 0, 16'd99);      // 32 skipped
    dut.ic.rom.mem[33] = enc_i(OP_ADDI, 3, 0, 16'd144);      // 33 ADDI R3, R0, 144
    dut.ic.rom.mem[34] = {OP_JR, 5'd0, 5'd3, 16'h0};         // 34 JR   R3  (word 36)
    dut.ic.rom.mem[35] = enc_i(OP_ADDI, 12, 0, 16'd99);      // 35 skipped
    dut.ic.rom.mem[36] = 32'h0;                              // 36 NOP
    dut.ic.rom.mem[37] = {OP_HALT, 26'b0};                   // 37 HALT

    // start-up: pc_src = 11 forces next_pc to 0, so word 0 is fetched
    idle_word; pc_src = 2'b11;
    tick;
    check_pc(0, "pc after start");
    check(opcode, OP_ADDI, "first instruction fetched");

    do_itype(F_ADD);                                      // 0
    check_reg(1, 5, "ADDI R1");
    check_pc(1, "pc after first instr");
    do_itype(F_ADD);                                      // 1
    check_reg(2, 7, "ADDI R2");

    do_rtype(F_ADD);                                      // 2
    check_reg(3, 12, "ADD");
    do_rtype(F_SUB);                                      // 3
    check_reg(4, 2, "SUB");

    do_itype(F_ADD);                                      // 4
    check_reg(5, 32'hFFFFFFFD, "ADDI negative immediate");
    do_rtype(F_SLT);                                      // 5
    check_reg(6, 1, "SLT signed");
    do_itype(F_SGT);                                      // 6
    check_reg(7, 1, "SGTI");
    do_itype(F_SRA);                                      // 7
    check_reg(8, 32'hFFFFFFFE, "SRAI");

    do_itype(F_LUI);                                      // 8
    check_reg(9, 32'h12340000, "LUI");
    do_itype(F_OR);                                       // 9
    check_reg(9, 32'h12348765, "ORI zero extends");

    do_st;                                                // 10
    check(dut.dc.dr.mem[2], 32'h12348765, "ST wrote word 2");
    do_ld;                                                // 11
    check_reg(10, 32'h12348765, "LD");
    check_pc(12, "pc after LD (only advances once)");

    do_rtype(F_MUL);                                      // 12
    check_reg(11, 32'hFFFFFFEB, "MUL low word (7 * -3)");
    do_mulu;                                              // 13
    check(dut.rf.hi, 32'hFFFFFFFF, "MULU hi");
    check(dut.rf.lo, 32'hFFFFFFF1, "MULU lo");
    check_reg(1, 5, "MULU leaves R1 alone");
    do_mfhl(3'b011);                                      // 14
    check_reg(12, 32'hFFFFFFFF, "MFHI");
    do_mfhl(3'b100);                                      // 15
    check_reg(13, 32'hFFFFFFF1, "MFLO");

    do_branch(3'b001, 3'b001);                            // 16 BEQ taken
    check_pc(18, "BEQ taken");
    do_branch(3'b010, 3'b001);                            // 18 BNE not taken
    check_pc(19, "BNE not taken");
    do_itype(F_ADD);                                      // 19
    check_reg(14, 1, "instruction after BNE ran");
    do_branch(3'b011, 3'b001);                            // 20 BLT taken
    check_pc(22, "BLT taken");
    do_branch(3'b001, 3'b010);                            // 22 BZ not taken
    check_pc(23, "BZ not taken");
    do_itype(F_ADD);                                      // 23
    check_reg(14, 11, "ADDI R14, R14, 10");
    do_branch(3'b001, 3'b010);                            // 24 BZ taken
    check_pc(26, "BZ taken");
    do_itype(F_LUI);                                      // 26
    check_reg(6, 32'h80000000, "LUI R6");
    do_branch(3'b111, 3'b001);                            // 27 BV taken
    check_pc(29, "BV taken");
    check_reg(14, 11, "skipped ADDI didn't run");

    do_jal;                                               // 29
    check_pc(31, "JAL target");
    check_reg(15, 30 * 4, "JAL link address");
    do_jump;                                              // 31
    check_pc(33, "J target");

    do_itype(F_ADD);                                      // 33
    check_reg(3, 144, "ADDI R3 for JR");
    do_jr;                                                // 34
    check_pc(36, "JR target");
    check(opcode, OP_NOP, "NOP fetched after JR");

    do_nop;                                               // 36
    check_pc(37, "pc after NOP");
    check(opcode, OP_HALT, "HALT fetched at the end");

    // none of the skipped instructions should have run
    check_reg(12, 32'hFFFFFFFF, "R12 still holds MFHI result");
    check_reg(14, 11, "R14 still 11");
    check_reg(0, 0, "R0 is zero");

    // pc_enable low: pc and instruction stay put
    idle_word; pc_enable = 0; ic_enable = 0;
    tick; tick;
    check_pc(37, "pc frozen when pc_enable=0");
    check(opcode, OP_HALT, "instruction frozen when ic_enable=0");

    if (errors == 0) $display("tb_data_path: all %0d checks passed", checks);
    else             $display("tb_data_path: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
