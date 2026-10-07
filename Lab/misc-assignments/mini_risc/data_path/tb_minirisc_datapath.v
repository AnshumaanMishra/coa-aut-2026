`timescale 1ns / 1ps
// ============================================================================
// MiniRISC Assignment 1B - behavioural testbench
// The data_path is re-instantiated here (same wiring as data_path.v) so every
// internal signal is visible in the waveform. A minimal decoder inside the
// testbench generates the control signals (no full FSM needed for 1B).
// ============================================================================
module tb_minirisc_datapath;

  // ---------------- clock / reset ----------------
  reg clk = 1'b0;
  reg reset = 1'b1;
  always #5 clk = ~clk;  // 10 ns period

  // ---------------- control signals (driven by mini decoder) ----------------
  reg pc_enable, ic_enable, hi_lo_enable, reg_write, mem_read, mem_write;
  reg alu_src, is_branch, force_rs_zero;
  reg [2:0] rt_sel, br_type;
  reg [1:0] reg_dst, pc_src, reg_in_src;
  reg [5:0] alu_func;

  // rst_pc rises 1 ns after t=0 so next_pc makes a real X -> 0 transition;
  // otherwise a combinational ROM can miss the time-0 address event and keep
  // ROM[0] unloaded (instruction 0 would then read as X).
  reg rst_pc = 1'b0;
  initial #1 rst_pc = 1'b1;

  // ---------------- datapath wires ----------------
  wire [31:0] next_pc, pc_out, inc_pc;
  wire [4:0] rs, rd, rt, shamt;
  wire [15:0] imm;
  wire [25:0] jta;
  wire [5:0] opcode, fn_sel;
  wire [4:0] rd_in, rt_addr, rs_addr;
  wire [31:0] rs_out, rt_out, reg_in_hi, reg_in_lo;
  wire [31:0] imm_se, imm_ext, alu_src_rt_in, alu_out_lo;
  wire ovfl, gt, lt, ge, le, eq, ne;
  wire [31:0] data_cache_output;

  // PC is a BYTE address in this project (steps of 4), so word index = PC >> 2.
  // Set PC_SHIFT = 0 if your PC steps by 1.
  localparam PC_SHIFT = 2;
  wire [31:0] pc_idx = pc_out >> PC_SHIFT;

  // Reconstructed 32-bit instruction word (R, I and branch formats share this layout)
  wire [31:0] instr_word = {opcode, rd, rs, imm};

  // ---------------- datapath instantiation ----------------
  program_counter pc (
      .clk(clk), .next_pc(next_pc), .pc_write_en(pc_enable), .pc_out(pc_out));

  instruction_cache ic (
      .clk(clk), .ena(1'b1), .ic_enable(ic_enable), .pc(next_pc),
      .rs(rs), .rt(rt), .rd(rd), .shamt(shamt), .imm(imm), .jta(jta),
      .opcode(opcode), .fn_sel(fn_sel));

  mux_4to1 #(.WIDTH(5)) reg_dst_mux (
      .I0(rt), .I1(rd), .I2(5'b10001), .I3(5'b01111), .sel(reg_dst), .O(rd_in));

  mux_8to1 #(.WIDTH(5)) rt_sel_mux (
      .I0(rt), .I1(rd), .I2(5'b0), .I3(5'b10000), .I4(5'b10001),
      .I5(5'b0), .I6(5'b0), .I7(5'b0), .sel(rt_sel), .O(rt_addr));

  mux_2to1 #(.WIDTH(5)) force_rs_zero_mux (
      .I0(rs), .I1(5'b0), .sel(force_rs_zero), .O(rs_addr));

  register_file rf (
      .clk(clk), .reg_write(reg_write), .hi_lo_enable(hi_lo_enable),
      .rs(rs_addr), .rt(rt_addr), .rd(rd_in),
      .reg_in_hi(reg_in_hi), .reg_in_lo(reg_in_lo),
      .rs_out(rs_out), .rt_out(rt_out));

  sign_extender #(.WIDTH(32)) se (.imm_in(imm), .se_imm(imm_se));

  mux_2to1 #(.WIDTH(32)) imm_ext_mux (
      .I0(imm_se), .I1({16'b0, imm}),
      .sel(alu_src & (alu_func[5:3] == 3'b011)), .O(imm_ext));

  mux_2to1 #(.WIDTH(32)) alu_src_rt_in_mux (
      .I0(rt_out), .I1(imm_ext), .sel(alu_src), .O(alu_src_rt_in));

  alu al_unit (
      .x(rs_out), .y(alu_src_rt_in), .alu_func(alu_func),
      .hi_lo_enable(hi_lo_enable), .ovfl(ovfl),
      .alu_out_hi(reg_in_hi), .alu_out_lo(alu_out_lo),
      .lt(lt), .gt(gt), .le(le), .ge(ge), .eq(eq), .ne(ne));

  data_cache dc (
      .clk(clk), .address(alu_out_lo), .data_input(rt_out),
      .read(mem_read), .write(mem_write), .data_out(data_cache_output));

  mux_4to1 #(.WIDTH(32)) reg_in_mux (
      .I0(data_cache_output), .I1(alu_out_lo), .I2(inc_pc), .I3(32'b0),
      .sel(reg_in_src), .O(reg_in_lo));

  next_address_decoder nad (
      .rt(rt_out), .rs(rs_out), .jta(jta), .pc(pc_out),
      .lt(lt), .gt(gt), .le(le), .ge(ge), .eq(eq), .ne(ne), .ovfl(ovfl),
      .br_type(br_type), .is_branch(is_branch), .pc_src(pc_src),
      .incr_pc(inc_pc), .next_pc(next_pc));

  // ---------------- minimal decoder (control signals) ----------------
  always @* begin
    pc_enable = 1'b1;  ic_enable = 1'b1;  hi_lo_enable = 1'b0;
    reg_write = 1'b0;  force_rs_zero = 1'b0;  rt_sel = 3'b000;
    reg_dst = 2'b01;   alu_src = 1'b0;  alu_func = 6'b000000;
    pc_src = 2'b00;    br_type = 3'b000; is_branch = 1'b0;
    mem_read = 1'b0;   mem_write = 1'b0; reg_in_src = 2'b01;

    if (reset) begin
      pc_src = rst_pc ? 2'b11 : 2'b00; // force next_pc = 0 during start-up
    end else begin
      case (opcode)
        6'b000000: ;                   // NOP
        6'b111111: begin               // HALT: freeze PC and instruction
          pc_enable = 1'b0;
          ic_enable = 1'b0;
        end
        6'b100000: begin               // R-type: fn field is the ALU code
          reg_write = 1'b1;
          alu_func  = fn_sel;
        end
        6'b110000: begin reg_write = 1; alu_src = 1; alu_func = 6'b010000; end // ADDI
        6'b110001: begin reg_write = 1; alu_src = 1; alu_func = 6'b010001; end // SUBI
        6'b110010: begin reg_write = 1; alu_src = 1; alu_func = 6'b011000; end // ANDI
        6'b110011: begin reg_write = 1; alu_src = 1; alu_func = 6'b011001; end // ORI
        6'b110100: begin reg_write = 1; alu_src = 1; alu_func = 6'b011011; end // NORI
        6'b110101: begin reg_write = 1; alu_src = 1; alu_func = 6'b011100; end // XORI
        6'b110110: begin reg_write = 1; alu_src = 1; alu_func = 6'b100000; end // SLLI
        6'b110111: begin reg_write = 1; alu_src = 1; alu_func = 6'b100001; end // SRLI
        6'b111000: begin reg_write = 1; alu_src = 1; alu_func = 6'b100010; end // SRAI
        6'b111001: begin reg_write = 1; alu_src = 1; alu_func = 6'b001000; end // SLTI
        6'b111010: begin reg_write = 1; alu_src = 1; alu_func = 6'b001001; end // SGTI
        6'b111011: begin reg_write = 1; alu_src = 1; alu_func = 6'b001010; end // SLEI
        6'b111100: begin reg_write = 1; alu_src = 1; alu_func = 6'b001011; end // SGEI
        6'b111101: begin reg_write = 1; alu_src = 1; alu_func = 6'b001100; end // SEQI
        6'b111110: begin reg_write = 1; alu_src = 1; alu_func = 6'b001101; end // SNEI
        default: ;
      endcase
    end
  end

  // ---------------- expected results ----------------
  // index = PC value of the instruction
  //  0 ADDI R1,R0,#5      1 ADDI R2,R0,#7      2 ADD  R3,R1,R2
  //  3 SUB  R4,R1,R2      4 AND  R5,R1,R2      5 SLL  R6,R2,R1
  //  6 SLT  R7,R4,R1      7 ADDI R0,R0,#99     8 ADD  R9,R0,R1
  //  9 ADD  R10,R0,R0    10 ADDI R11,R1,#-3   11 SRAI R12,R4,#1
  // 12 HALT
  localparam LAST = 11;
  reg [31:0] ex_instr [0:12];
  reg [31:0] ex_x     [0:12];
  reg [31:0] ex_y     [0:12];
  reg [31:0] ex_res   [0:12];
  reg [4:0]  ex_rd    [0:12];
  integer errors = 0;
  integer checks = 0;
  integer i;

  initial begin
    ex_instr[0]  = 32'hC0200005; ex_x[0]  = 32'd0;        ex_y[0]  = 32'd5;         ex_res[0]  = 32'd5;         ex_rd[0]  = 1;
    ex_instr[1]  = 32'hC0400007; ex_x[1]  = 32'd0;        ex_y[1]  = 32'd7;         ex_res[1]  = 32'd7;         ex_rd[1]  = 2;
    ex_instr[2]  = 32'h80611010; ex_x[2]  = 32'd5;        ex_y[2]  = 32'd7;         ex_res[2]  = 32'd12;        ex_rd[2]  = 3;
    ex_instr[3]  = 32'h80811011; ex_x[3]  = 32'd5;        ex_y[3]  = 32'd7;         ex_res[3]  = 32'hFFFFFFFE;  ex_rd[3]  = 4;
    ex_instr[4]  = 32'h80A11018; ex_x[4]  = 32'd5;        ex_y[4]  = 32'd7;         ex_res[4]  = 32'd5;         ex_rd[4]  = 5;
    ex_instr[5]  = 32'h80C20820; ex_x[5]  = 32'd7;        ex_y[5]  = 32'd5;         ex_res[5]  = 32'd224;       ex_rd[5]  = 6;
    ex_instr[6]  = 32'h80E40808; ex_x[6]  = 32'hFFFFFFFE; ex_y[6]  = 32'd5;         ex_res[6]  = 32'd1;         ex_rd[6]  = 7;
    ex_instr[7]  = 32'hC0000063; ex_x[7]  = 32'd0;        ex_y[7]  = 32'd99;        ex_res[7]  = 32'd99;        ex_rd[7]  = 0;
    ex_instr[8]  = 32'h81200810; ex_x[8]  = 32'd0;        ex_y[8]  = 32'd5;         ex_res[8]  = 32'd5;         ex_rd[8]  = 9;
    ex_instr[9]  = 32'h81400010; ex_x[9]  = 32'd0;        ex_y[9]  = 32'd0;         ex_res[9]  = 32'd0;         ex_rd[9]  = 10;
    ex_instr[10] = 32'hC161FFFD; ex_x[10] = 32'd5;        ex_y[10] = 32'hFFFFFFFD;  ex_res[10] = 32'd2;         ex_rd[10] = 11;
    ex_instr[11] = 32'hE1840001; ex_x[11] = 32'hFFFFFFFE; ex_y[11] = 32'd1;         ex_res[11] = 32'hFFFFFFFF;  ex_rd[11] = 12;
    ex_instr[12] = 32'hFC000000; ex_x[12] = 32'd0;        ex_y[12] = 32'd0;         ex_res[12] = 32'd0;         ex_rd[12] = 0;
  end

  // ---------------- self-checking + trace (mid-cycle sampling) ----------------
  always @(negedge clk) begin
    if (!reset && pc_idx <= LAST) begin
      checks = checks + 1;
      $display("t=%0t PC=%0d INSTR=%h op=%b rd=%0d rs=%0d rt=%0d imm=%h | A=%h B=%h (src=%b) func=%b -> Y=%h | we=%b wr_addr=%0d wb=%h",
               $time, pc_out, instr_word, opcode, rd, rs, rt, imm,
               rs_out, alu_src_rt_in, alu_src, alu_func, alu_out_lo,
               reg_write, rd_in, reg_in_lo);
      if (instr_word !== ex_instr[pc_idx]) begin
        errors = errors + 1;
        $display("  FAIL fetch: got %h expected %h", instr_word, ex_instr[pc_idx]);
      end
      if (rs_out !== ex_x[pc_idx] || alu_src_rt_in !== ex_y[pc_idx]) begin
        errors = errors + 1;
        $display("  FAIL operands: A=%h (exp %h) B=%h (exp %h)",
                 rs_out, ex_x[pc_idx], alu_src_rt_in, ex_y[pc_idx]);
      end
      if (alu_out_lo !== ex_res[pc_idx]) begin
        errors = errors + 1;
        $display("  FAIL result: got %h expected %h", alu_out_lo, ex_res[pc_idx]);
      end
      if (reg_write !== 1'b1 || rd_in !== ex_rd[pc_idx] || reg_in_lo !== ex_res[pc_idx]) begin
        errors = errors + 1;
        $display("  FAIL write-back: we=%b rd=%0d wb=%h", reg_write, rd_in, reg_in_lo);
      end
      // simultaneous two-port read on a register-register instruction
      if (pc_idx == 2)
        $display("  >> Two read ports at once: R%0d=%0d and R%0d=%0d", rs_addr, rs_out, rt_addr, rt_out);
      if (pc_idx == 7)
        $display("  >> Attempted write to R0 (value %0d); write must be ignored", alu_out_lo);
      if (pc_idx == 8 || pc_idx == 9)
        $display("  >> R0 read as %h (must be 00000000)", rs_out);
    end
  end

  // ---------------- stimulus ----------------
  initial begin
    $dumpfile("tb_minirisc_datapath.vcd");
    $dumpvars(0, tb_minirisc_datapath);

    // hold reset for three rising edges so PC = 0 and instruction 0 is latched
    repeat (3) @(posedge clk);
    #1 reset = 1'b0;

    // run until HALT has been reached, plus a few cycles to show PC frozen
    wait (pc_idx == 12);
    repeat (4) @(posedge clk);

    if (pc_idx !== 32'd12) begin
      errors = errors + 1;
      $display("FAIL: PC not frozen on HALT (PC=%0d)", pc_out);
    end

    $display("--------------------------------------------------");
    $display("Instructions checked: %0d, errors: %0d", checks, errors);
    if (errors == 0 && checks == LAST + 1) $display("RESULT: PASS");
    else                                   $display("RESULT: FAIL");
    $finish;
  end

  // watchdog
  initial begin
    #2000;
    $display("TIMEOUT");
    $finish;
  end

endmodule
