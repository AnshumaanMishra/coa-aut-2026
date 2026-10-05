`timescale 1ns/1ps
// =============================================================================
//  MiniRISC behavioural testbench
//
//  Strategy
//  --------
//  * A tiny assembler (tasks rr/ri/ld/st/br/...) writes machine code straight
//    into the instruction ROM through hierarchical references, so the test
//    does NOT depend on inputs/program.mem.
//  * A golden instruction-set simulator (ISS, tasks iss_*) runs the same
//    program on shadow state. After the DUT halts, registers, $hi/$lo, all of
//    data memory, final PC, the per-instruction PC trace and the cycle count
//    are compared against the ISS.
//  * Key semantics are additionally checked against HAND-COMPUTED constants
//    (ex_reg / ex_mem / bt tables) so a shared misunderstanding between the
//    ISS and the RTL cannot hide.
//  * Passive monitors run every cycle (R0==0, PC alignment, ROM/PC coherence,
//    X-free controls, store only on ST, ...).
//
//  Run from the project root (directory containing inputs/):
//     iverilog -g2012 -s mini_risc_tb -o build/tb.vvp $(find . -name '*.v')
//     vvp build/tb.vvp            (+vcd for waveform, +trace for a PC trace)
// =============================================================================
module mini_risc_tb;

  parameter integer MUL_CYCLES = 1;   // total cycles MUL/MULU occupy (RTL as supplied: 1)
  parameter integer N_RANDOM   = 400; // number of random programs
  parameter integer RANDOM_LEN = 60;  // instructions per random program

  // ---------------------------------------------------------------- DUT ----
  reg clk = 0, start = 0, reset = 0;
  mini_risc dut (.clk(clk), .start(start), .reset(reset));
  always #5 clk = ~clk;

  `define RF     dut.data.rf.registers
  `define RFHI   dut.data.rf.hi
  `define RFLO   dut.data.rf.lo
  `define ROM    dut.data.ic.rom.mem
  `define DMEM   dut.data.dc.dr.mem
  `define DSTATE dut.control.state
  `define PCV    dut.data.pc.pc_out

  // ------------------------------------------------------------- opcodes ---
  localparam [5:0] OP_NOP=6'b000000, OP_HALT=6'b111111, OP_R=6'b100000,
    OP_MFHI=6'b100001, OP_LI=6'b100010, OP_LUI=6'b100011, OP_MOVE=6'b100100,
    OP_LD=6'b100101, OP_ST=6'b100110, OP_MFLO=6'b100111,
    OP_J=6'b101000, OP_JAL=6'b101001, OP_JR=6'b101011,
    OP_ADDI=6'b110000, OP_SUBI=6'b110001, OP_ANDI=6'b110010, OP_ORI=6'b110011,
    OP_NORI=6'b110100, OP_XORI=6'b110101, OP_SLLI=6'b110110, OP_SRLI=6'b110111,
    OP_SRAI=6'b111000, OP_SLTI=6'b111001, OP_SGTI=6'b111010, OP_SLEI=6'b111011,
    OP_SGEI=6'b111100, OP_SEQI=6'b111101, OP_SNEI=6'b111110,
    OP_BEQ=6'b010000, OP_BZ=6'b010001, OP_BNE=6'b010010, OP_BLT=6'b010011,
    OP_BLE=6'b010100, OP_BGT=6'b010101, OP_BGE=6'b010110, OP_BV=6'b010111;
  localparam [5:0] F_ADD=6'b010000, F_SUB=6'b010001, F_MUL=6'b010010, F_MULU=6'b010011,
    F_AND=6'b011000, F_OR=6'b011001, F_NOT=6'b011010, F_NOR=6'b011011, F_XOR=6'b011100,
    F_SLL=6'b100000, F_SRL=6'b100001, F_SRA=6'b100010,
    F_SLT=6'b001000, F_SGT=6'b001001, F_SLE=6'b001010, F_SGE=6'b001011,
    F_SEQ=6'b001100, F_SNE=6'b001101;

  // --------------------------------------------------------- bookkeeping ---
  integer n_pass = 0, n_fail = 0, n_progs = 0, n_instr_checked = 0;
  string  cur = "init";
  integer seed = 32'h5EED1234;
  integer ncv = 13;          // number of corner values swept (7 with +quick)
  integer nrand_run;         // random programs to run
  reg nomulu = 0;            // +nomulu : keep MULU out of the random programs

  task fail(input string msg);
    begin
      n_fail = n_fail + 1;
      if (n_fail <= 60 || $test$plusargs("verbose")) $display("  [FAIL] (%0s) %0s", cur, msg);
      else if (n_fail == 61) $display("  ... further failures suppressed ...");
    end
  endtask

  task ok; begin n_pass = n_pass + 1; end endtask

  task chk32(input string what, input [31:0] got, input [31:0] exp);
    begin
      if (got === exp) ok;
      else fail($sformatf("%0s: got %h expected %h", what, got, exp));
    end
  endtask

  task section(input string s); begin $display("\n=== %0s ===", s); end endtask

  // --------------------------------------------------------- shadow state ---
  reg [31:0] sreg [0:15];
  reg [31:0] shi, slo;
  reg [31:0] sdm  [0:1023];
  reg [31:0] pmem [0:1023];
  reg [31:0] pctrace [0:262143];
  integer ipc, isteps, inld, inmul, tcount;
  reg ihalt;
  integer wp;                       // assembler write pointer (word index)

  // -------------------------------------------------------- ref functions ---
  function [31:0] sext16(input [15:0] x); sext16 = {{16{x[15]}}, x}; endfunction

  function [31:0] ref_rfn(input [5:0] fn, input [31:0] a, input [31:0] b);
    reg signed [31:0] sa, sb;
    begin
      sa = a; sb = b;
      case (fn)
        F_ADD: ref_rfn = a + b;
        F_SUB: ref_rfn = a - b;
        F_MUL: ref_rfn = a * b;           // low 32 bits (identical signed/unsigned)
        F_AND: ref_rfn = a & b;
        F_OR : ref_rfn = a | b;
        F_NOT: ref_rfn = ~a;
        F_NOR: ref_rfn = ~(a | b);
        F_XOR: ref_rfn = a ^ b;
        F_SLL: ref_rfn = a << b[4:0];
        F_SRL: ref_rfn = a >> b[4:0];
        F_SRA: ref_rfn = sa >>> b[4:0];
        F_SLT: ref_rfn = (sa <  sb);
        F_SGT: ref_rfn = (sa >  sb);
        F_SLE: ref_rfn = (sa <= sb);
        F_SGE: ref_rfn = (sa >= sb);
        F_SEQ: ref_rfn = (a == b);
        F_SNE: ref_rfn = (a != b);
        default: ref_rfn = 32'hxxxxxxxx;
      endcase
    end
  endfunction

  function [5:0] i2fn(input [5:0] op);
    case (op)
      OP_ADDI: i2fn = F_ADD;  OP_SUBI: i2fn = F_SUB;  OP_ANDI: i2fn = F_AND;
      OP_ORI : i2fn = F_OR;   OP_NORI: i2fn = F_NOR;  OP_XORI: i2fn = F_XOR;
      OP_SLLI: i2fn = F_SLL;  OP_SRLI: i2fn = F_SRL;  OP_SRAI: i2fn = F_SRA;
      OP_SLTI: i2fn = F_SLT;  OP_SGTI: i2fn = F_SGT;  OP_SLEI: i2fn = F_SLE;
      OP_SGEI: i2fn = F_SGE;  OP_SEQI: i2fn = F_SEQ;  OP_SNEI: i2fn = F_SNE;
      default: i2fn = 6'bxxxxxx;
    endcase
  endfunction

  function is_iop(input [5:0] op); is_iop = (op >= OP_ADDI && op <= OP_SNEI); endfunction
  function is_logic_iop(input [5:0] op);
    is_logic_iop = (op==OP_ANDI || op==OP_ORI || op==OP_NORI || op==OP_XORI);
  endfunction
  function is_bop(input [5:0] op); is_bop = (op >= OP_BEQ && op <= OP_BV); endfunction

  // a = rs value, b = value of the register in the rd field
  function ref_br(input [5:0] op, input [31:0] a, input [31:0] b);
    reg signed [31:0] sa, sb; reg [31:0] d;
    begin
      sa = a; sb = b; d = a - b;
      case (op)
        OP_BEQ: ref_br = (a == b);
        OP_BZ : ref_br = (a == 32'd0);
        OP_BNE: ref_br = (a != b);
        OP_BLT: ref_br = (sa <  sb);
        OP_BLE: ref_br = (sa <= sb);
        OP_BGT: ref_br = (sa >  sb);
        OP_BGE: ref_br = (sa >= sb);
        OP_BV : ref_br = ((a[31] ^ b[31]) & (a[31] ^ d[31]));
        default: ref_br = 1'b0;
      endcase
    end
  endfunction

  function is_defined_op(input [5:0] op);
    begin
      is_defined_op = (op == OP_NOP) || (op == OP_HALT) || (op >= OP_BEQ && op <= OP_BV) ||
                      (op >= OP_R && op <= OP_MFLO) || (op == OP_J) || (op == OP_JAL) ||
                      (op == OP_JR) || (op >= OP_ADDI && op <= OP_SNEI);
    end
  endfunction

  // ------------------------------------------------------------------ ISS ---
  task swr(input [4:0] r, input [31:0] v);
    begin if (r[3:0] != 0 && r[4] == 0) sreg[r[3:0]] = v; end
  endtask

  task iss_step;
    reg [31:0] w, a, b, ea, nxt, p64a;
    reg [5:0] op, fn;
    reg [4:0] rd, rs, rt;
    reg [15:0] imm;
    reg [63:0] prod;
    begin
      w = pmem[ipc]; op = w[31:26]; rd = w[25:21]; rs = w[20:16]; rt = w[15:11];
      imm = w[15:0]; fn = w[5:0];
      isteps = isteps + 1;
      nxt = ipc + 1;
      if (!is_defined_op(op) || op == OP_HALT) begin
        ihalt = 1;
      end else begin
        pctrace[tcount] = ipc * 4; tcount = tcount + 1;
        if (op == OP_R) begin
          a = sreg[rs[3:0]]; b = sreg[rt[3:0]];
          if (fn == F_MULU) begin
            prod = $signed(a) * $signed(b);      // MULU = signed 64-bit product -> HI:LO
            shi = prod[63:32]; slo = prod[31:0]; inmul = inmul + 1;
          end else begin
            if (fn == F_MUL) inmul = inmul + 1;
            swr(rd, ref_rfn(fn, a, b));
          end
        end else if (is_iop(op)) begin
          a = sreg[rs[3:0]];
          b = is_logic_iop(op) ? {16'b0, imm} : sext16(imm);
          swr(rd, ref_rfn(i2fn(op), a, b));
        end else begin
          case (op)
            OP_NOP : ;
            OP_LI  : swr(rd, sext16(imm));
            OP_LUI : swr(rd, {imm, 16'b0});
            OP_MOVE: swr(rd, sreg[rs[3:0]]);
            OP_MFHI: swr(rd, shi);
            OP_MFLO: swr(rd, slo);
            OP_LD  : begin ea = sreg[rs[3:0]] + sext16(imm); swr(rd, sdm[ea[11:2]]); inld = inld + 1; end
            OP_ST  : begin ea = sreg[rs[3:0]] + sext16(imm); sdm[ea[11:2]] = sreg[rd[3:0]]; end
            OP_J   : nxt = w[25:0];
            OP_JAL : begin swr(5'd15, (ipc + 1) * 4); nxt = w[25:0]; end
            OP_JR  : nxt = sreg[rs[3:0]] >> 2;
            default: begin
              if (is_bop(op))
                if (ref_br(op, sreg[rs[3:0]], sreg[rd[3:0]])) nxt = ipc + 1 + sext16(imm);
            end
          endcase
        end
        ipc = nxt;
        if (ipc >= 1024 || ipc < 0) ihalt = 1;
      end
    end
  endtask

  task iss_run(input integer maxsteps);
    begin
      ipc = 0; isteps = 0; inld = 0; inmul = 0; tcount = 0; ihalt = 0;
      while (!ihalt && isteps < maxsteps) iss_step;
    end
  endtask

  // ------------------------------------------------------------ assembler ---
  task put(input [31:0] w);
    begin pmem[wp] = w; `ROM[wp] = w; wp = wp + 1; end
  endtask
  task rr (input [5:0] fn, input [4:0] rd, input [4:0] rs, input [4:0] rt);
    put({OP_R, rd, rs, rt, 5'd0, fn});
  endtask
  task rrs(input [5:0] fn, input [4:0] rd, input [4:0] rs, input [4:0] rt, input [4:0] shamt);
    put({OP_R, rd, rs, rt, shamt, fn});    // shamt field is junk for the DUT
  endtask
  task ri (input [5:0] op, input [4:0] rd, input [4:0] rs, input [15:0] imm);
    put({op, rd, rs, imm});
  endtask
  task ldw(input [4:0] rd, input integer off, input [4:0] rs);
    reg [15:0] o; begin o = off; put({OP_LD, rd, rs, o}); end
  endtask
  task stw(input [4:0] rd, input integer off, input [4:0] rs);
    reg [15:0] o; begin o = off; put({OP_ST, rd, rs, o}); end
  endtask
  task jmp(input [5:0] op, input integer tgt); put({op, tgt[25:0]}); endtask
  task jr (input [4:0] rs); put({OP_JR, 5'd0, rs, 16'd0}); endtask
  task br (input [5:0] op, input [4:0] rd, input [4:0] rs, input integer tgt);
    reg [15:0] o; begin o = tgt - (wp + 1); put({op, rd, rs, o}); end
  endtask
  task brf(input [5:0] op, input [4:0] rd, input [4:0] rs, output integer h);
    begin h = wp; put({op, rd, rs, 16'd0}); end
  endtask
  task fixb(input integer h, input integer tgt);
    reg [31:0] w; reg [15:0] o;
    begin o = tgt - (h + 1); w = pmem[h]; w[15:0] = o; pmem[h] = w; `ROM[h] = w; end
  endtask
  task fixj(input integer h, input integer tgt);
    reg [31:0] w;
    begin w = pmem[h]; w[25:0] = tgt; pmem[h] = w; `ROM[h] = w; end
  endtask
  task halt; put({OP_HALT, 26'd0}); endtask
  task nop;  put(32'd0);            endtask
  task li  (input [4:0] rd, input [15:0] imm); ri(OP_LI, rd, 5'd0, imm); endtask
  task load32(input [4:0] rd, input [31:0] v);
    begin ri(OP_LUI, rd, 5'd0, v[31:16]); ri(OP_ORI, rd, rd, v[15:0]); end
  endtask

  // --------------------------------------------------- program environment ---
  function [31:0] dpat(input integer i); dpat = 32'hD000_0000 + i; endfunction

  task new_prog;
    integer i;
    begin
      for (i = 0; i < 1024; i = i + 1) begin
        `ROM[i] = {OP_HALT, 26'd0}; pmem[i] = {OP_HALT, 26'd0};
        `DMEM[i] = dpat(i);         sdm[i]  = dpat(i);
      end
      for (i = 0; i < 16; i = i + 1) begin `RF[i] = 0; sreg[i] = 0; end
      `RFHI = 0; `RFLO = 0; shi = 0; slo = 0;
      wp = 0;
    end
  endtask

  task setr(input integer r, input [31:0] v);
    begin if (r != 0) begin `RF[r] = v; sreg[r] = v; end end
  endtask
  task sethilo(input [31:0] h, input [31:0] l);
    begin `RFHI = h; `RFLO = l; shi = h; slo = l; end
  endtask
  task setm(input integer i, input [31:0] v);
    begin `DMEM[i] = v; sdm[i] = v; end
  endtask

  // ---------------------------------------------------------- run control ---
  reg        mon_en = 0;
  integer    exec_cycles;
  integer    trace_k;
  reg        trace_bad;
  reg        hold_start = 0;
  reg        timed_out;

  task clk_n(input integer n); begin repeat (n) @(negedge clk); end endtask

  task do_reset;
    begin
      @(negedge clk); reset = 1; start = 0;
      clk_n(2);
      reset = 0;
    end
  endtask

  task run_prog(input integer max_cycles);
    integer c, i;
    reg [31:0] pc_snap, rf_snap [0:15];
    reg [31:0] hi_snap, lo_snap;
    begin
      mon_en = 0;
      do_reset;
      clk_n(2);                                   // IDLE: PC<=0, ROM<=mem[0]
      mon_en = 1; trace_k = 0; trace_bad = 0; timed_out = 0;
      if (`DSTATE !== 2'b00) fail("not in IDLE after reset");
      if (`PCV !== 32'd0)    fail($sformatf("PC not 0 in IDLE (%h)", `PCV));
      start = 1; @(negedge clk); start = hold_start;
      exec_cycles = 0; c = 0;
      while (`DSTATE !== 2'b11 && c < max_cycles) begin
        if (`DSTATE === 2'b01 || `DSTATE === 2'b10) exec_cycles = exec_cycles + 1;
        @(negedge clk); c = c + 1;
      end
      if (`DSTATE !== 2'b11) begin timed_out = 1; fail($sformatf("TIMEOUT after %0d cycles (PC=%h)", c, `PCV)); end
      // stability once halted
      pc_snap = `PCV; for (i = 0; i < 16; i = i + 1) rf_snap[i] = `RF[i];
      hi_snap = `RFHI; lo_snap = `RFLO;
      clk_n(4);
      if (`PCV !== pc_snap) fail("PC moved after HALT/DONE");
      for (i = 0; i < 16; i = i + 1) if (`RF[i] !== rf_snap[i]) fail($sformatf("R%0d changed after DONE", i));
      if (`RFHI !== hi_snap || `RFLO !== lo_snap) fail("HI/LO changed after DONE");
      if (`DSTATE !== 2'b11) fail("left DONE state without reset");
      mon_en = 0; start = 0; hold_start = 0;
    end
  endtask

  // Compare DUT final state against ISS shadow state
  task compare_all;
    integer i;
    begin
      for (i = 0; i < 16; i = i + 1)
        if (`RF[i] !== sreg[i]) fail($sformatf("R%0d: DUT %h  ISS %h", i, `RF[i], sreg[i]));
        else ok;
      if (`RFHI !== shi) fail($sformatf("HI: DUT %h  ISS %h", `RFHI, shi)); else ok;
      if (`RFLO !== slo) fail($sformatf("LO: DUT %h  ISS %h", `RFLO, slo)); else ok;
      for (i = 0; i < 1024; i = i + 1)
        if (`DMEM[i] !== sdm[i]) fail($sformatf("DMEM[%0d] (byte addr %0d): DUT %h  ISS %h", i, i*4, `DMEM[i], sdm[i]));
      ok;
      if (`PCV !== ipc * 4) fail($sformatf("final PC: DUT %h  ISS %h", `PCV, ipc*4)); else ok;
      if (!timed_out) begin
        if (exec_cycles !== isteps + inld + inmul * (MUL_CYCLES - 1))
          fail($sformatf("cycle count: DUT %0d  expected %0d (instr %0d, LD %0d, MUL %0d)",
               exec_cycles, isteps + inld + inmul*(MUL_CYCLES-1), isteps, inld, inmul));
        else ok;
        if (trace_k !== tcount) fail($sformatf("executed-instruction count: DUT %0d ISS %0d", trace_k, tcount));
        else ok;
      end
    end
  endtask

  // run ISS, run DUT, compare
  task go(input string nm, input integer maxsteps);
    begin
      cur = nm; n_progs = n_progs + 1;
      iss_run(maxsteps);
      if (!ihalt) fail("ISS did not halt (program bug)");
      n_instr_checked = n_instr_checked + isteps;
      run_prog(3 * (isteps + inld + inmul * MUL_CYCLES) + 200);
      compare_all;
    end
  endtask

  // hand-computed expectations against the DUT
  task ex_reg(input integer r, input [31:0] v);
    begin if (`RF[r] === v) ok; else fail($sformatf("hand-check R%0d: DUT %h  expected %h", r, `RF[r], v)); end
  endtask
  task ex_hilo(input [31:0] h, input [31:0] l);
    begin
      if (`RFHI === h && `RFLO === l) ok;
      else fail($sformatf("hand-check HI/LO: DUT %h/%h expected %h/%h", `RFHI, `RFLO, h, l));
    end
  endtask
  task ex_mem(input integer wi, input [31:0] v);
    begin if (`DMEM[wi] === v) ok; else fail($sformatf("hand-check DMEM[%0d]: DUT %h expected %h", wi, `DMEM[wi], v)); end
  endtask
  task ex_pc(input integer byte_addr);
    begin if (`PCV === byte_addr) ok; else fail($sformatf("hand-check PC: DUT %h expected %h", `PCV, byte_addr)); end
  endtask

  // ------------------------------------------------------------- monitors ---
  // 1. R0 stays zero, PC word aligned, ROM output matches PC, no X on controls
  always @(negedge clk) if (mon_en) begin
    if (`RF[0] !== 32'd0) fail("R0 is non-zero");
    if (`PCV[1:0] !== 2'b00) fail("PC not word aligned");
    if (^{dut.pc_enable, dut.ic_enable, dut.reg_write, dut.mem_write, dut.mem_read,
          dut.hi_lo_enable} === 1'bx) fail("X on control signal");
    if (dut.data.ic.rom.douta !== `ROM[`PCV[11:2]])
      fail($sformatf("ROM output (%h) != ROM[PC=%h] (%h): PC/instruction desynchronised",
                     dut.data.ic.rom.douta, `PCV, `ROM[`PCV[11:2]]));
    if (dut.mem_write && dut.opcode !== OP_ST) fail("mem_write asserted for non-ST opcode");
    if (dut.mem_write && (`DSTATE === 2'b11 || `DSTATE === 2'b00)) fail("mem_write in IDLE/DONE");
    if (dut.reg_write && (`DSTATE === 2'b11 || `DSTATE === 2'b00)) fail("reg_write in IDLE/DONE");
    if (dut.opcode === OP_LD && `DSTATE === 2'b01 && (dut.reg_write || dut.pc_enable))
      fail("LD: reg_write/pc_enable asserted in first (address) cycle");
    if (dut.opcode === OP_LD && `DSTATE === 2'b10 && !(dut.reg_write && dut.pc_enable))
      fail("LD: commit cycle must assert reg_write and pc_enable");
  end

  // 2. Per-instruction PC trace vs ISS (checked on each commit cycle)
  always @(negedge clk) if (mon_en && (`DSTATE === 2'b01 || `DSTATE === 2'b10) && dut.pc_enable) begin
    if (trace_k < tcount && !trace_bad) begin
      if (`PCV !== pctrace[trace_k]) begin
        trace_bad = 1;
        fail($sformatf("PC trace diverged at instruction #%0d: DUT PC=%h, ISS PC=%h", trace_k, `PCV, pctrace[trace_k]));
      end
    end
    trace_k = trace_k + 1;
    if ($test$plusargs("trace")) $display("    t=%0t PC=%h instr=%h", $time, `PCV, dut.data.ic.rom.douta);
  end

  // ------------------------------------------------------------ test data ---
  reg [31:0] CV [0:12];
  reg [5:0]  RFN [0:16];
  reg [5:0]  IOP [0:14];
  reg [5:0]  BOP [0:7];
  reg [15:0] IMMV [0:7];

  task init_tables;
    begin
      CV[0]=0; CV[1]=1; CV[2]=32'hFFFFFFFF; CV[3]=32'h7FFFFFFF; CV[4]=32'h80000000;
      CV[5]=32'h80000001; CV[6]=32'h12345678; CV[7]=32'hDEADBEEF; CV[8]=5;
      CV[9]=32'hFFFFFFF9; CV[10]=31; CV[11]=32; CV[12]=32'h0000FFFF;
      RFN[0]=F_ADD; RFN[1]=F_SUB; RFN[2]=F_MUL; RFN[3]=F_AND; RFN[4]=F_OR; RFN[5]=F_NOT;
      RFN[6]=F_NOR; RFN[7]=F_XOR; RFN[8]=F_SLL; RFN[9]=F_SRL; RFN[10]=F_SRA; RFN[11]=F_SLT;
      RFN[12]=F_SGT; RFN[13]=F_SLE; RFN[14]=F_SGE; RFN[15]=F_SEQ; RFN[16]=F_SNE;
      IOP[0]=OP_ADDI; IOP[1]=OP_SUBI; IOP[2]=OP_ANDI; IOP[3]=OP_ORI; IOP[4]=OP_NORI;
      IOP[5]=OP_XORI; IOP[6]=OP_SLLI; IOP[7]=OP_SRLI; IOP[8]=OP_SRAI; IOP[9]=OP_SLTI;
      IOP[10]=OP_SGTI; IOP[11]=OP_SLEI; IOP[12]=OP_SGEI; IOP[13]=OP_SEQI; IOP[14]=OP_SNEI;
      BOP[0]=OP_BEQ; BOP[1]=OP_BZ; BOP[2]=OP_BNE; BOP[3]=OP_BLT; BOP[4]=OP_BLE;
      BOP[5]=OP_BGT; BOP[6]=OP_BGE; BOP[7]=OP_BV;
      IMMV[0]=16'h0000; IMMV[1]=16'h0001; IMMV[2]=16'h7FFF; IMMV[3]=16'h8000;
      IMMV[4]=16'hFFFF; IMMV[5]=16'h00FF; IMMV[6]=16'h1234; IMMV[7]=16'hFFE1;
    end
  endtask

  function [31:0] rnd32(input integer dummy);
    reg [31:0] r;
    begin
      r = $random(seed);
      case ({$random(seed)} % 8)
        0: rnd32 = CV[{$random(seed)} % 13];
        1: rnd32 = r & 32'h0000_00FF;
        2: rnd32 = r | 32'hFFFF_0000;
        default: rnd32 = r;
      endcase
    end
  endfunction
  function integer rnd(input integer max);   // 0..max
    rnd = {$random(seed)} % (max + 1);
  endfunction

  // =========================================================================
  //                           DIRECTED TESTS
  // =========================================================================

  // Assignment 1B style sample: ADDI/ADDI/ADD
  task t_smoke;
    begin
      section("Smoke test (assignment example)");
      new_prog;
      ri(OP_ADDI,1,0,5); ri(OP_ADDI,2,0,7); rr(F_ADD,3,1,2); halt;
      go("smoke", 100);
      ex_reg(1,5); ex_reg(2,7); ex_reg(3,12); ex_reg(0,0);
      ex_pc(12);                       // HALT sits at word 3
    end
  endtask

  // IDLE behaviour, start handling, async reset, restart
  task t_control;
    integer i;
    reg [31:0] r1;
    begin
      section("Control: IDLE / start / reset / restart");
      new_prog;
      ri(OP_ADDI,1,1,1); jmp(OP_J,0);                  // R1++ forever
      mon_en = 0; do_reset; clk_n(2); mon_en = 1; cur = "idle";
      // start low for many cycles -> nothing happens
      clk_n(25);
      ex_reg(1,0); ex_pc(0);
      if (`DSTATE !== 2'b00) fail("left IDLE without start");
      // start pulse, run a while
      start = 1; @(negedge clk); start = 0;
      clk_n(20);
      if (`DSTATE !== 2'b01) fail("not RUN after start");
      r1 = `RF[1];
      if (r1 < 5) fail($sformatf("loop not progressing, R1=%0d", r1)); else ok;
      // 2-cycle loop body -> R1 increments once per 2 cycles
      clk_n(10);
      chk32("R1 increment rate (1 per 2 cycles)", `RF[1], r1 + 5);
      // start pulse while running must be ignored
      start = 1; clk_n(3); start = 0;
      if (`DSTATE !== 2'b01) fail("start glitch disturbed RUN");
      // asynchronous reset between clock edges
      @(posedge clk); #2; reset = 1; #1;
      if (`DSTATE !== 2'b00) fail("async reset did not force IDLE immediately");
      #3; reset = 0;
      clk_n(2);
      ex_pc(0);
      if (`DSTATE !== 2'b00) fail("not IDLE after reset release");
      // registers survive reset (RTL doesn't reset RF) and execution restarts from 0
      r1 = `RF[1];
      start = 1; @(negedge clk); start = 0; clk_n(11);
      if (`RF[1] <= r1) fail("restart after reset did not resume execution"); else ok;
      // hold start high through a whole run
      mon_en = 0;
      new_prog; ri(OP_ADDI,1,0,3); ri(OP_ADDI,2,1,4); halt;
      hold_start = 1;
      go("start held high", 50);
      ex_reg(1,3); ex_reg(2,7);
      // Re-run after DONE using reset (R1 accumulates)
      new_prog; ri(OP_ADDI,1,1,1); halt;
      go("rerun #1", 50); ex_reg(1,1);
      cur = "rerun #2"; run_prog(50); ex_reg(1,2);
      cur = "rerun #3"; run_prog(50); ex_reg(1,3);
      mon_en = 0;
    end
  endtask

  // HALT / NOP / illegal opcodes
  task t_halt_nop_illegal;
    integer k;
    reg [5:0] op;
    reg [31:0] junk;
    begin
      section("NOP / HALT / illegal opcodes");
      // HALT stops PC, later instructions do not execute
      new_prog; ri(OP_ADDI,1,0,1); halt; ri(OP_ADDI,1,1,1); ri(OP_ADDI,2,0,9); halt;
      go("halt stops", 50); ex_reg(1,1); ex_reg(2,0); ex_pc(4);
      // HALT as very first instruction
      new_prog; halt; ri(OP_ADDI,1,0,1);
      go("halt first", 50); ex_reg(1,0); ex_pc(0);
      // NOPs advance PC, change nothing; junk fields ignored
      new_prog; setr(1, 32'h11111111); setr(2, 32'h22222222);
      nop; nop; put(32'h03FF_FFFF); put(32'h0000_0001); nop;
      ri(OP_ADDI,3,0,3); halt;
      go("nops", 50); ex_reg(1,32'h11111111); ex_reg(2,32'h22222222); ex_reg(3,3); ex_pc(24);
      // long NOP sled, then op
      new_prog; repeat (200) nop; ri(OP_ADDI,4,0,44); halt;
      go("nop sled", 400); ex_reg(4,44); ex_pc(804);
      // all undefined opcodes terminate execution (-> DONE) without side effects
      for (k = 0; k < 64; k = k + 1) begin
        op = k;
        if (!is_defined_op(op)) begin
          new_prog; ri(OP_ADDI,1,0,1); junk = {op, 26'h2AAAAAA}; put(junk); ri(OP_ADDI,1,1,1);
          go($sformatf("illegal opcode %b", op), 50); ex_reg(1,1); ex_pc(4);
          new_prog; ri(OP_ADDI,1,0,1); junk = {op, 26'h0}; put(junk); ri(OP_ADDI,1,1,1);
          go($sformatf("illegal opcode %b (zero fields)", op), 50); ex_reg(1,1); ex_pc(4);
        end
      end
    end
  endtask

  // Hand-computed R-type table
  task t_rtype_hand;
    begin
      section("R-type: hand-computed results");
      new_prog;
      setr(1,12); setr(2,10); setr(3,32'hFFFFFFFB); setr(4,3);
      rr(F_ADD,5,1,2); rr(F_SUB,6,1,2); rr(F_SUB,7,2,1); rr(F_MUL,8,1,3);
      rr(F_AND,9,1,2); rr(F_OR,10,1,2); rr(F_XOR,11,1,2); rr(F_NOR,12,1,2);
      rr(F_NOT,13,1,0); rr(F_SLL,14,1,4); rr(F_SRL,15,3,4);
      // second batch overwrites R5..R12
      rr(F_SRA,5,3,4); rr(F_SLT,6,3,1); rr(F_SGT,7,3,1); rr(F_SLE,8,1,1);
      rr(F_SGE,9,2,1); rr(F_SEQ,10,1,1); rr(F_SNE,11,1,2); rr(F_SLT,12,1,3);
      halt;
      go("R-type hand", 100);
      ex_reg(1,12); ex_reg(2,10); ex_reg(3,32'hFFFFFFFB); ex_reg(4,3);
      ex_reg(5,32'hFFFFFFFF); ex_reg(6,1); ex_reg(7,0); ex_reg(8,1); ex_reg(9,0);
      ex_reg(10,1); ex_reg(11,1); ex_reg(12,0);
      ex_reg(13,32'hFFFFFFF3); ex_reg(14,96); ex_reg(15,32'h1FFFFFFF);
      // first-batch results observed separately
      new_prog;
      setr(1,12); setr(2,10); setr(3,32'hFFFFFFFB);
      rr(F_ADD,5,1,2); rr(F_SUB,6,1,2); rr(F_SUB,7,2,1); rr(F_MUL,8,1,3);
      rr(F_AND,9,1,2); rr(F_OR,10,1,2); rr(F_XOR,11,1,2); rr(F_NOR,12,1,2); halt;
      go("R-type hand 1st batch", 100);
      ex_reg(5,22); ex_reg(6,2); ex_reg(7,32'hFFFFFFFE); ex_reg(8,32'hFFFFFFC4);
      ex_reg(9,8); ex_reg(10,14); ex_reg(11,6); ex_reg(12,32'hFFFFFFF1);
    end
  endtask

  // Hand-computed I-type table (checks zero- vs sign-extension)
  task t_itype_hand;
    begin
      section("I-type: hand-computed results (extension rules)");
      new_prog;
      setr(1,100);
      ri(OP_ADDI,2,1,25);  ri(OP_SUBI,3,1,101); ri(OP_ANDI,4,1,16'h000F);
      ri(OP_ORI,5,1,16'h8000); ri(OP_NORI,6,1,16'h00FF); ri(OP_XORI,7,1,16'hFFFF);
      ri(OP_SLLI,8,1,4); ri(OP_SRLI,9,1,2); ri(OP_SRAI,10,3,4);
      ri(OP_SLTI,11,1,101); ri(OP_SGTI,12,1,100); ri(OP_SLEI,13,1,100);
      ri(OP_SGEI,14,1,101); ri(OP_SEQI,15,1,100); ri(OP_SNEI,4,1,100);
      halt;
      go("I-type hand", 100);
      ex_reg(2,125); ex_reg(3,32'hFFFFFFFF); ex_reg(4,0); ex_reg(5,32'h00008064);
      ex_reg(6,32'hFFFFFF00); ex_reg(7,32'h0000FF9B); ex_reg(8,1600); ex_reg(9,25);
      ex_reg(10,32'hFFFFFFFF); ex_reg(11,1); ex_reg(12,0); ex_reg(13,1); ex_reg(14,0); ex_reg(15,1);

      new_prog;   // extension corner cases
      setr(1,32'hFFFFFFFF); setr(2,32'hFFFF8000); setr(3,32'h00000000); setr(4, 32'hFFFF0000);
      ri(OP_ANDI,5,1,16'hFFFF);   // zero-ext -> 0x0000FFFF
      ri(OP_ORI ,6,3,16'h8000);   // zero-ext -> 0x00008000
      ri(OP_ADDI,7,3,16'h8000);   // sign-ext -> 0xFFFF8000
      ri(OP_ADDI,8,3,16'hFFFF);   // -1
      ri(OP_XORI,9,1,16'hFFFF);   // 0xFFFF0000
      ri(OP_NORI,10,3,16'h0001);  // 0xFFFFFFFE
      ri(OP_SLTI,11,2,16'h8000);  // -32768 < -32768 ? 0
      ri(OP_SLTI,12,4,16'h8000);  // -65536 < -32768 ? 1  (imm sign-extended)
      ri(OP_SGTI,13,4,16'h8000);  // 0
      ri(OP_SLEI,14,2,16'h8000);  // 1
      ri(OP_SLLI,15,1,16'hFFE1);  // shift amount = imm[4:0] = 1
      halt;
      go("I-type extension", 100);
      ex_reg(5,32'h0000FFFF); ex_reg(6,32'h00008000); ex_reg(7,32'hFFFF8000);
      ex_reg(8,32'hFFFFFFFF); ex_reg(9,32'hFFFF0000); ex_reg(10,32'hFFFFFFFE);
      ex_reg(11,0); ex_reg(12,1); ex_reg(13,0); ex_reg(14,1); ex_reg(15,32'hFFFFFFFE);
    end
  endtask

  // Exhaustive R-type: all functions x corner operand pairs
  task t_rtype_corners;
    integer f, i, j;
    begin
      section("R-type: every function x corner-value operand pairs");
      for (f = 0; f < 17; f = f + 1)
        for (i = 0; i < ncv; i = i + 1)
          for (j = 0; j < ncv; j = j + 1) begin
            new_prog; setr(1, CV[i]); setr(2, CV[j]);
            rrs(RFN[f], 3, 1, 2, 5'h15);          // junk shamt field must be ignored
            halt;
            go($sformatf("R fn=%b a=%h b=%h", RFN[f], CV[i], CV[j]), 20);
          end
    end
  endtask

  // Exhaustive I-type
  task t_itype_corners;
    integer f, i, j;
    begin
      section("I-type: every opcode x corner values x immediates");
      for (f = 0; f < 15; f = f + 1)
        for (i = 0; i < ncv; i = i + 1)
          for (j = 0; j < 8; j = j + 1) begin
            new_prog; setr(1, CV[i]);
            ri(IOP[f], 2, 1, IMMV[j]); halt;
            go($sformatf("I op=%b a=%h imm=%h", IOP[f], CV[i], IMMV[j]), 20);
          end
    end
  endtask

  // Operand/destination aliasing and R0 rules
  task t_regfile;
    integer r;
    begin
      section("Register file: aliasing, R0 protection, all registers");
      // dest == source, both sources same
      new_prog; setr(1,32'h12345678);
      rr(F_ADD,1,1,1); rr(F_SUB,2,1,1); rr(F_XOR,3,1,1); rr(F_SLT,4,1,1); rr(F_SEQ,5,1,1);
      halt;
      go("alias", 20); ex_reg(1,32'h2468ACF0); ex_reg(2,0); ex_reg(3,0); ex_reg(4,0); ex_reg(5,1);
      // writes to R0 are ignored for every instruction class
      new_prog; setr(1,32'hCAFEBABE); setr(2,7); sethilo(32'hAAAA5555, 32'h5555AAAA);
      setm(2, 32'h0BADF00D);
      rr(F_ADD,0,1,2);  ri(OP_ADDI,0,1,5);  li(0,16'h1234);  ri(OP_LUI,0,0,16'hFFFF);
      ri(OP_MOVE,0,1,0); ri(OP_MFHI,0,0,0); ri(OP_MFLO,0,0,0); ldw(0,8,0);
      rr(F_MUL,0,1,2); rr(F_SLT,0,1,2);
      rr(F_ADD,3,0,0);         // R0 + R0 = 0
      rr(F_ADD,4,0,1);         // R0 + R1
      rr(F_SUB,5,0,1);         // 0 - R1
      halt;
      go("R0 writes ignored", 50);
      ex_reg(0,0); ex_reg(3,0); ex_reg(4,32'hCAFEBABE); ex_reg(5,32'h35014542);
      // every register R1..R15 independently writable/readable (no aliasing)
      new_prog;
      for (r = 1; r < 16; r = r + 1) li(r, 16'h0101 * r);
      for (r = 1; r < 16; r = r + 1) stw(r, 4*r, 0);
      for (r = 1; r < 16; r = r + 1) rr(F_ADD, 0, r, r);   // read each reg on rs and rt ports, discard
      halt;
      go("walk all regs", 200);
      for (r = 1; r < 16; r = r + 1) begin ex_reg(r, 16'h0101 * r); ex_mem(r, 16'h0101 * r); end
      // read ports are independent: rs=Rx, rt=Ry for all (x,y) with distinct values
      new_prog;
      for (r = 1; r < 16; r = r + 1) setr(r, 32'h1000_0000 + r*32'h0001_0001);
      for (r = 1; r < 15; r = r + 1) rr(F_SUB, r, r+1, r);   // R[r] = R[r+1]-R[r] = 0x00010001
      halt;
      go("port independence", 100);
    end
  endtask

  // LI / LUI / MOVE / constants
  task t_constants;
    begin
      section("LI / LUI / MOVE / MFHI / MFLO / constants");
      new_prog; setr(5, 32'h00000064); setr(6, 32'h00000777); setr(7, 32'h00000888);
      li(1,16'h0005); li(2,16'hFFFF); li(3,16'h8000); li(4,16'h7FFF);
      ri(OP_LI,8,5,16'h0042);                 // rs field junk: LI must force rs=R0 -> 0x42
      ri(OP_LUI,9,0,16'h8000);                // 0x80000000
      ri(OP_LUI,10,5,16'h1234);               // rs junk ignored -> 0x12340000
      load32(11,32'hDEADBEEF);
      load32(12,32'h00008001);                // ORI zero-extends
      load32(13,32'hFFFF8000);
      ri(OP_MOVE,14,11,5'd6);                 // rt field junk (R6) ignored -> copy R11
      ri(OP_MOVE,15,14,5'd7);
      halt;
      go("constants", 100);
      ex_reg(1,5); ex_reg(2,32'hFFFFFFFF); ex_reg(3,32'hFFFF8000); ex_reg(4,32'h00007FFF);
      ex_reg(8,32'h42); ex_reg(9,32'h80000000); ex_reg(10,32'h12340000);
      ex_reg(11,32'hDEADBEEF); ex_reg(12,32'h00008001); ex_reg(13,32'hFFFF8000);
      ex_reg(14,32'hDEADBEEF); ex_reg(15,32'hDEADBEEF);
      // MOVE from every register
      new_prog; begin : mv integer r; for (r = 1; r < 15; r = r + 1) setr(r, 32'hA000_0000 + r); end
      begin : mv2 integer r; for (r = 1; r < 15; r = r + 1) ri(OP_MOVE, 15, r, 5'd31 - r); end
      halt;
      go("MOVE all sources", 50); ex_reg(15, 32'hA000_000E);
      // MFHI / MFLO with junk rs / rt fields, including R0 as rt-field alias check
      new_prog; sethilo(32'hCAFEF00D, 32'h0BADCAFE); setr(5,32'h55); setr(6,32'h66);
      ri(OP_MFHI,1,5,5'd6); ri(OP_MFLO,2,5,5'd6);
      ri(OP_MFHI,3,0,0);    ri(OP_MFLO,4,0,0);
      halt;
      go("MFHI/MFLO", 50);
      ex_reg(1,32'hCAFEF00D); ex_reg(2,32'h0BADCAFE); ex_reg(3,32'hCAFEF00D); ex_reg(4,32'h0BADCAFE);
    end
  endtask

  // Multiplication
  task t_mul;
    integer i, j;
    reg [63:0] p;
    begin
      section("MUL / MULU / MFHI / MFLO");
      // hand-computed: -7 * 6 = -42
      new_prog; li(1,16'hFFF9); li(2,6); sethilo(32'h11111111, 32'h22222222);
      rr(F_MUL,3,1,2); halt;
      go("MUL -7*6", 20); ex_reg(3,32'hFFFFFFD6); ex_hilo(32'h11111111, 32'h22222222); // MUL must not touch HI/LO
      // MUL: neg*neg, big overflow low bits
      new_prog; setr(1,32'hFFFFFFFF); setr(2,32'hFFFFFFFF); setr(4,32'h7FFFFFFF); setr(5,32'h00010001);
      rr(F_MUL,3,1,2); rr(F_MUL,6,4,4); rr(F_MUL,7,5,5); halt;
      go("MUL misc", 20);
      ex_reg(3,1); ex_reg(6,32'h00000001); ex_reg(7,32'h00020001);
      // MULU: rd must not be written, result in HI/LO
      new_prog; setr(1,32'h00010000); setr(2,32'h00010000); setr(3,32'hBAD0BAD0);
      rr(F_MULU,3,1,2); ri(OP_MFHI,4,0,0); ri(OP_MFLO,5,0,0); halt;
      go("MULU 2^16*2^16", 20);
      ex_reg(3,32'hBAD0BAD0); ex_reg(4,1); ex_reg(5,0); ex_hilo(1,0);
      // MULU = signed 64-bit product (HI:LO). (-1)*(-1) = 1
      new_prog; setr(1,32'hFFFFFFFF); setr(2,32'hFFFFFFFF);
      rr(F_MULU,3,1,2); halt;
      go("MULU (-1)*(-1)", 20); ex_hilo(32'h00000000, 32'h00000001);
      new_prog; setr(1,32'h80000000); setr(2,32'h00000002);
      rr(F_MULU,3,1,2); halt;
      go("MULU MIN*2 = -2^32", 20); ex_hilo(32'hFFFFFFFF, 32'h00000000);
      new_prog; setr(1,32'h00000003); setr(2,32'h80000000);
      rr(F_MULU,3,1,2); halt;
      go("MULU 3*MIN = -3*2^31", 20); ex_hilo(32'hFFFFFFFE, 32'h80000000);
      // MULU with positive operands whose product exceeds 2^31 but fits in 32 bits
      new_prog; setr(1,1000000); setr(2,3000);
      rr(F_MULU,3,1,2); halt;
      go("MULU 1e6*3e3", 20); ex_hilo(32'h0, 32'hB2D05E00);   // 3,000,000,000
      // sweep corner pairs for MUL and MULU
      for (i = 0; i < ncv; i = i + 1)
        for (j = 0; j < ncv; j = j + 1) begin
          new_prog; setr(1,CV[i]); setr(2,CV[j]); sethilo(32'hFEEDFACE, 32'hFACEFEED);
          rr(F_MUL,3,1,2); halt;
          go($sformatf("MUL a=%h b=%h", CV[i], CV[j]), 20);
          new_prog; setr(1,CV[i]); setr(2,CV[j]); setr(3,32'h77777777);
          rr(F_MULU,3,1,2); ri(OP_MFHI,4,0,0); ri(OP_MFLO,5,0,0); halt;
          go($sformatf("MULU a=%h b=%h", CV[i], CV[j]), 20);
        end
      // random MUL/MULU
      for (i = 0; i < 200; i = i + 1) begin
        new_prog; setr(1,rnd32(0)); setr(2,rnd32(0));
        rr(F_MULU,3,1,2); ri(OP_MFHI,4,0,0); ri(OP_MFLO,5,0,0); rr(F_MUL,6,1,2); halt;
        go($sformatf("rand MULU/MUL #%0d a=%h b=%h", i, sreg[1], sreg[2]), 20);
      end
    end
  endtask

  // Data memory
  task t_memory;
    integer i;
    begin
      section("LD / ST (base + sign-extended offset, word-index = addr[11:2])");
      new_prog;
      for (i = 0; i < 8; i = i + 1) setm(i, 10*(i+1));         // same as inputs/data_ram.mem
      ldw(1,0,0); ldw(2,4,0); ldw(3,28,0);
      li(4,8); ldw(5,8,4);        // addr 16 -> 50
      ldw(6,-4,4);                // addr 4  -> 20
      stw(1,64,0);                // mem[16] = 10
      ldw(7,64,0);                // 10
      rr(F_ADD,8,1,2);            // 30
      stw(8,0,4);                 // addr 8 -> mem[2] = 30
      ldw(9,8,0);                 // load-after-store -> 30
      stw(0,12,0);                // mem[3] = 0
      ldw(10,12,0);               // 0
      ldw(0,4,0);                 // load into R0 ignored
      ldw(4,0,4);                 // rd == rs : R4 = mem[2] = 30
      ldw(11,20,0); rr(F_ADD,12,11,11);   // load then immediate use: 60 -> 120
      li(13,16'hFFFF); stw(13,128,0);     // store negative
      ldw(14,128,0);
      halt;
      go("memory basics", 200);
      ex_reg(1,10); ex_reg(2,20); ex_reg(3,80); ex_reg(5,50); ex_reg(6,20); ex_reg(7,10);
      ex_reg(8,30); ex_reg(9,30); ex_reg(10,0); ex_reg(0,0); ex_reg(4,30);
      ex_reg(11,60); ex_reg(12,120); ex_reg(14,32'hFFFFFFFF);
      ex_mem(16,10); ex_mem(2,30); ex_mem(3,0); ex_mem(32,32'hFFFFFFFF);

      // LD must take 2 cycles, ST 1 cycle
      new_prog; ldw(1,0,0); halt;   go("LD cycle count", 20);
      if (exec_cycles !== 3) fail($sformatf("LD+HALT should take 3 cycles, took %0d", exec_cycles)); else ok;
      new_prog; stw(1,0,0); halt;   go("ST cycle count", 20);
      if (exec_cycles !== 2) fail($sformatf("ST+HALT should take 2 cycles, took %0d", exec_cycles)); else ok;

      // back-to-back loads, stores of every register, large positive/negative offsets
      new_prog;
      for (i = 0; i < 16; i = i + 1) setm(i, 32'hC0DE0000 + i);
      for (i = 0; i < 16; i = i + 1) ldw(1, 4*i, 0);
      halt;
      go("16 consecutive LDs", 200); ex_reg(1, 32'hC0DE000F);
      new_prog; setr(1, 32'h200); setr(2, 32'h0000AAAA); setr(3, 32'h0000BBBB);
      stw(2, 100, 1);      // addr 0x264 -> idx 153
      stw(3, -100, 1);     // addr 0x19C -> idx 103
      ldw(4, 100, 1); ldw(5, -100, 1); ldw(6, 0, 1);
      halt;
      go("big +/- offsets", 100);
      ex_reg(4,32'hAAAA); ex_reg(5,32'hBBBB); ex_mem(153, 32'hAAAA); ex_mem(103,32'hBBBB);
      ex_reg(6, dpat(128));
      // store followed immediately by load of neighbour & same address (RAM read-first behaviour must not leak)
      new_prog; setr(1,32'h13572468); setr(2,32'h2468ACE0);
      stw(1,40,0); ldw(3,40,0); stw(2,40,0); ldw(4,40,0); ldw(5,44,0);
      halt;
      go("ST/LD same address", 100);
      ex_reg(3,32'h13572468); ex_reg(4,32'h2468ACE0); ex_reg(5,dpat(11));
      // array sum and copy loops
      new_prog;
      for (i = 0; i < 8; i = i + 1) setm(i, 10*(i+1));
      li(1,0); li(2,0); li(4,32);
      // loop: LD R3,0(R1); ADD R2,R2,R3; ST R3,128(R1); ADDI R1,R1,4; BNE R4,R1,loop
      begin : arr integer lp; lp = wp;
        ldw(3,0,1); rr(F_ADD,2,2,3); stw(3,128,1); ri(OP_ADDI,1,1,4); br(OP_BNE,4,1,lp); end
      halt;
      go("array sum+copy", 500);
      ex_reg(2,360); for (i = 0; i < 8; i = i + 1) ex_mem(32+i, 10*(i+1));
    end
  endtask

  // Branches: hand table + exhaustive
  reg [31:0] bt_a, bt_b;
  task bt(input [5:0] op, input [31:0] a, input [31:0] b, input taken);
    begin
      new_prog; setr(1,a); setr(2,b);
      br(op, 2, 1, 3);          // target = word 3 (skip the "not taken" marker)
      li(3,1);                  // word 1: executes only when NOT taken
      halt;                     // word 2
      halt;                     // word 3  (taken path lands here)
      go($sformatf("branch op=%b rs=%h rd=%h", op, a, b), 20);
      ex_reg(3, taken ? 0 : 1);
      ex_pc(taken ? 12 : 8);
    end
  endtask

  task t_branches;
    integer i, j, k;
    begin
      section("Conditional branches");
      // ---- hand-specified truth table (rs = a, rd-field register = b) ----
      bt(OP_BEQ, 5, 5, 1);               bt(OP_BEQ, 5, 6, 0);
      bt(OP_BNE, 5, 5, 0);               bt(OP_BNE, 5, 6, 1);
      bt(OP_BZ , 0, 77, 1);              bt(OP_BZ , 1, 0, 0);  bt(OP_BZ, 32'h80000000, 0, 0);
      bt(OP_BLT, 3, 4, 1);               bt(OP_BLT, 4, 4, 0);  bt(OP_BLT, 5, 4, 0);
      bt(OP_BLT, 32'hFFFFFFFF, 1, 1);    bt(OP_BLT, 1, 32'hFFFFFFFF, 0);
      bt(OP_BLT, 32'h80000000, 1, 1);    bt(OP_BLT, 32'h7FFFFFFF, 32'h80000000, 0); // overflow case
      bt(OP_BLT, 32'h80000000, 32'h7FFFFFFF, 1);                                    // overflow case
      bt(OP_BLE, 3, 4, 1);               bt(OP_BLE, 4, 4, 1);  bt(OP_BLE, 5, 4, 0);
      bt(OP_BGT, 5, 4, 1);               bt(OP_BGT, 4, 4, 0);  bt(OP_BGT, 3, 4, 0);
      bt(OP_BGT, 1, 32'hFFFFFFFF, 1);    bt(OP_BGT, 32'h7FFFFFFF, 32'h80000000, 1);
      bt(OP_BGE, 5, 4, 1);               bt(OP_BGE, 4, 4, 1);  bt(OP_BGE, 3, 4, 0);
      bt(OP_BGE, 32'h80000000, 32'h7FFFFFFF, 0);
      bt(OP_BV , 32'h7FFFFFFF, 32'hFFFFFFFF, 1);   // MAX - (-1) overflows
      bt(OP_BV , 32'h80000000, 1, 1);              // MIN - 1 overflows
      bt(OP_BV , 0, 32'h80000000, 1);              // 0 - MIN overflows
      bt(OP_BV , 5, 3, 0);  bt(OP_BV, 1, 1, 0);  bt(OP_BV, 32'h7FFFFFFF, 1, 0);
      bt(OP_BV , 32'h80000000, 32'hFFFFFFFF, 0);   // MIN - (-1) = MIN+1, no overflow
      // BZ must ignore the rd field entirely (rd register is non-zero here)
      // ---- exhaustive over corner pairs, expected taken from ref model ----
      for (k = 0; k < 8; k = k + 1)
        for (i = 0; i < ncv; i = i + 1)
          for (j = 0; j < ncv; j = j + 1)
            bt(BOP[k], CV[i], CV[j], ref_br(BOP[k], CV[i], CV[j]));
      // ---- random pairs ----
      for (k = 0; k < 8; k = k + 1)
        for (i = 0; i < 60; i = i + 1) begin
          bt_a = rnd32(0); bt_b = (rnd(3) == 0) ? bt_a : rnd32(0);
          bt(BOP[k], bt_a, bt_b, ref_br(BOP[k], bt_a, bt_b));
        end
      // big offsets: forward over ~1000 words then backward over ~1000 words
      new_prog;
      begin : big
        integer K, h;
        K = 1000;
        br(OP_BEQ,0,0,K+1);                     // word 0 -> K+1
        li(5,5);                                // word 1
        halt;                                   // word 2
        for (h = 3; h <= K; h = h + 1) li(9, 9);// skipped filler (R9 must stay 0)
        li(4,4);                                // word K+1
        br(OP_BEQ,0,0,1);                       // word K+2 -> 1  (offset -(K+2))
      end
      go("branch +/-1000 words", 100);
      ex_reg(4,4); ex_reg(5,5); ex_reg(9,0);
      // branch to itself-adjacent targets: offset 0 (fall through) and -1 (loop with counter)
      new_prog;
      br(OP_BEQ,0,0,1);                         // offset 0: taken, target = next
      li(1,1);
      li(2,3);
      // loop: ADDI R3,R3,1 ; SUBI R2,R2,1 ; BNE R0,R2,loop
      begin : lp2 integer lp; lp = wp; ri(OP_ADDI,3,3,1); ri(OP_SUBI,2,2,1); br(OP_BNE,0,2,lp); end
      halt;
      go("offset 0 & small loop", 100); ex_reg(1,1); ex_reg(3,3); ex_reg(2,0);
    end
  endtask

  // Jumps
  task t_jumps;
    integer h1, h2;
    begin
      section("J / JAL / JR");
      new_prog;
      li(1,1);                    // 0
      jmp(OP_J, 4);               // 1
      li(1,99);                   // 2  skipped
      li(2,99);                   // 3  skipped
      li(2,2);                    // 4
      jmp(OP_JAL, 8);             // 5  -> R15 = 6*4 = 24
      li(3,3);                    // 6
      halt;                       // 7
      li(4,4);                    // 8
      jr(15);                     // 9  -> word 6
      go("J/JAL/JR", 100);
      ex_reg(1,1); ex_reg(2,2); ex_reg(3,3); ex_reg(4,4); ex_reg(15,24); ex_pc(28);

      new_prog;                   // JR to a computed address
      li(5,16);                   // 0
      jr(5);                      // 1
      li(1,1);                    // 2 skipped
      li(2,2);                    // 3 skipped
      li(3,3);                    // 4 (target = byte 16)
      halt;                       // 5
      go("JR computed", 100); ex_reg(1,0); ex_reg(2,0); ex_reg(3,3); ex_reg(5,16);

      new_prog;                   // call a leaf function three times
      jmp(OP_JAL, 5);             // 0  R15=4
      jmp(OP_JAL, 5);             // 1  R15=8
      jmp(OP_JAL, 5);             // 2  R15=12
      halt;                       // 3
      nop;                        // 4
      ri(OP_ADDI,1,1,1);          // 5 f:
      jr(15);                     // 6
      go("3 calls", 100); ex_reg(1,3); ex_reg(15,12); ex_pc(12);

      new_prog;                   // nested calls using memory stack
      li(14, 16'h0100);           // 0 sp = 0x100
      jmp(OP_JAL, 9);             // 1 call outer ; R15=8
      halt;                       // 2
      nop; nop; nop; nop; nop; nop;   // 3..8
      // outer (word 9): save RA, call inner, restore RA, ret
      stw(15,0,14);               // 9
      jmp(OP_JAL, 15);            // 10 call inner ; R15 = 44
      ldw(15,0,14);               // 11
      ri(OP_ADDI,2,2,10);         // 12
      jr(15);                     // 13
      nop;                        // 14
      ri(OP_ADDI,2,0,5);          // 15 inner
      jr(15);                     // 16
      go("nested calls", 200); ex_reg(2,15); ex_pc(8);

      new_prog;                   // backward J forming loop with BZ exit
      li(1,5);                    // 0
      brf(OP_BZ,0,1,h1);          // 1  while (R1 != 0)
      ri(OP_ADDI,2,2,3);          // 2
      ri(OP_SUBI,1,1,1);          // 3
      jmp(OP_J,1);                // 4
      fixb(h1, wp);
      halt;                       // 5
      go("while loop", 200); ex_reg(2,15);
      // JAL return-address value for various positions
      new_prog; repeat (37) nop; jmp(OP_JAL, 39); halt; jr(15);
      go("JAL ra at word 37", 100); ex_reg(15, 38*4);
    end
  endtask

  // Larger algorithms
  task t_programs;
    integer i, j, lp, outer, inner, t, h1, h2;
    reg [31:0] tmp;
    begin
      section("Algorithms (loops, memory, calls)");
      // sum 1..10
      new_prog; li(1,10); li(2,0);
      lp = wp; rr(F_ADD,2,2,1); ri(OP_SUBI,1,1,1); br(OP_BNE,0,1,lp); halt;
      go("sum 1..10", 500); ex_reg(2,55);
      // fibonacci(20)
      new_prog; li(1,0); li(2,1); li(4,20);
      lp = wp; rr(F_ADD,3,1,2); ri(OP_MOVE,1,2,0); ri(OP_MOVE,2,3,0); ri(OP_SUBI,4,4,1); br(OP_BNE,0,4,lp); halt;
      go("fibonacci", 1000); ex_reg(1,6765); ex_reg(2,10946);
      // factorial 10 using MUL
      new_prog; li(1,10); li(2,1);
      lp = wp; rr(F_MUL,2,2,1); ri(OP_SUBI,1,1,1); br(OP_BNE,0,1,lp); halt;
      go("factorial", 500); ex_reg(2,3628800);
      // GCD(48,18)
      new_prog; li(1,48); li(2,18);
      brf(OP_BEQ,2,1,h1);        // 2: if R1==R2 -> done
      brf(OP_BLT,2,1,h2);        // 3: if R1<R2 -> else
      rr(F_SUB,1,1,2);           // 4
      jmp(OP_J,2);               // 5
      fixb(h2, wp); rr(F_SUB,2,2,1);  // 6
      jmp(OP_J,2);               // 7
      fixb(h1, wp); halt;        // 8
      go("gcd", 500); ex_reg(1,6); ex_reg(2,6);
      // nested loops: 5x4 = 20 increments
      new_prog; li(1,5);
      outer = wp; li(2,4);
      inner = wp; ri(OP_ADDI,3,3,1); ri(OP_SUBI,2,2,1); br(OP_BNE,0,2,inner);
      ri(OP_SUBI,1,1,1); br(OP_BNE,0,1,outer); halt;
      go("nested loops", 1000); ex_reg(3,20);
      // bubble sort of 8 signed words (signed compare)
      new_prog;
      setm(0,50); setm(1,32'hFFFFFFFD); setm(2,7); setm(3,100); setm(4,0); setm(5,32'hFFFFFFEC); setm(6,7); setm(7,33);
      li(1,7);
      outer = wp; li(2,0); li(6,7);
      inner = wp; ldw(3,0,2); ldw(4,4,2);
      br(OP_BLE,4,3,wp+3);          // skip swap if R3 <= R4
      stw(4,0,2); stw(3,4,2);
      ri(OP_ADDI,2,2,4); ri(OP_SUBI,6,6,1); br(OP_BNE,0,6,inner);
      ri(OP_SUBI,1,1,1); br(OP_BNE,0,1,outer); halt;
      go("bubble sort", 5000);
      ex_mem(0,32'hFFFFFFEC); ex_mem(1,32'hFFFFFFFD); ex_mem(2,0); ex_mem(3,7);
      ex_mem(4,7); ex_mem(5,33); ex_mem(6,50); ex_mem(7,100);
      // Collatz steps for 27 (111 steps) - exercises SRL, AND, MUL-free odd step, branches
      new_prog; li(1,27); li(2,0);
      lp = wp;
      ri(OP_SEQI,3,1,1);          // R3 = (R1 == 1)
      brf(OP_BNE,0,3,h1);         // exit when R3 != 0
      ri(OP_ANDI,4,1,1);
      brf(OP_BZ,0,4,h2);          // even?
      rr(F_ADD,5,1,1); rr(F_ADD,1,5,1); ri(OP_ADDI,1,1,1);   // 3n+1
      ri(OP_ADDI,2,2,1); jmp(OP_J,lp);
      fixb(h2, wp);
      ri(OP_SRLI,1,1,1); ri(OP_ADDI,2,2,1); jmp(OP_J,lp);
      fixb(h1, wp); halt;
      go("collatz 27", 5000); ex_reg(2,111); ex_reg(1,1);
      // Matrix-style address generation: sum of a[i] * b[i] with MUL, dot product
      new_prog;
      for (i = 0; i < 8; i = i + 1) begin setm(i, i + 1); setm(16 + i, 2 * (i + 1) - 5); end
      li(1,0); li(2,0); li(5,32);
      lp = wp; ldw(3,0,1); ldw(4,64,1); rr(F_MUL,6,3,4); rr(F_ADD,2,2,6); ri(OP_ADDI,1,1,4); br(OP_BNE,5,1,lp); halt;
      go("dot product", 2000);
      tmp = 0; for (i = 0; i < 8; i = i + 1) tmp = tmp + (i+1) * (2*(i+1) - 5);
      ex_reg(2, tmp);
      // 64-bit accumulate with MULU/MFHI/MFLO (MAC-style)
      new_prog; setr(1,32'hFFFFFFF0); setr(2,32'h00000100);
      rr(F_MULU,0,1,2); ri(OP_MFLO,3,0,0); ri(OP_MFHI,4,0,0);
      rr(F_MULU,0,3,2); ri(OP_MFLO,5,0,0); ri(OP_MFHI,6,0,0); halt;
      go("MULU chain", 100);
    end
  endtask

  // Random regression: random programs vs ISS
  function [31:0] rand_instr(input integer pos, input integer len);
    integer kind, n, o;
    reg [4:0] rd, rs, rt;
    reg [15:0] imm;
    reg [31:0] w;
    begin
      kind = rnd(99);
      rd = rnd(15); if (rd == 13) rd = 12;       // R13 reserved as memory pointer
      rs = rnd(15); rt = rnd(15);
      imm = (rnd(3) == 0) ? IMMV[rnd(7)] : rnd32(0);
      n = 1 + rnd(2);
      if (pos + n + 1 > len) kind = rnd(83);      // not enough room for a forward transfer
      if (kind < 30)       w = {OP_R, rd, rs, rt, 5'(rnd(31)), RFN[rnd(16)]};
      else if (kind < 55)  w = {IOP[rnd(14)], rd, rs, imm};
      else if (kind < 61)  w = {OP_LI, rd, (rnd(1) ? 5'd0 : rs), imm};
      else if (kind < 63)  w = {OP_LUI, rd, rs, imm};
      else if (kind < 66)  w = {OP_MOVE, rd, rs, rt, 11'd0};
      else if (kind < 68)  w = {OP_MFHI, rd, rs, rt, 11'd0};
      else if (kind < 70)  w = {OP_MFLO, rd, rs, rt, 11'd0};
      else if (kind < 74)  w = nomulu ? 32'd0 : {OP_R, rd, rs, rt, 5'd0, F_MULU};
      else if (kind < 79)  begin o = 4 * rnd(127) - 256; imm = o; w = {OP_LD, rd, 5'd13, imm}; end
      else if (kind < 84)  begin o = 4 * rnd(127) - 256; imm = o; w = {OP_ST, rs, 5'd13, imm}; end
      else if (kind < 87)  w = 32'd0;
      else if (kind < 96)  begin imm = n; w = {BOP[rnd(7)], rd, rs, imm}; end
      else if (kind < 98)  w = {OP_J, 26'(pos + 1 + n)};
      else                 w = {OP_JAL, 26'(pos + 1 + n)};
      rand_instr = w;
    end
  endfunction

  task t_random;
    integer p, i, r;
    reg [31:0] w;
    begin
      section("Random program regression vs ISS");
      for (p = 0; p < nrand_run; p = p + 1) begin
        new_prog;
        for (r = 1; r < 16; r = r + 1) setr(r, rnd32(0));
        setr(13, 32'h100);
        sethilo(rnd32(0), rnd32(0));
        for (i = 0; i < 256; i = i + 1) setm(i, rnd32(0));
        for (i = 0; i < RANDOM_LEN; i = i + 1) begin
          w = rand_instr(i, RANDOM_LEN);
          put(w);
        end
        halt;
        go($sformatf("random program #%0d", p), 10000);
      end
    end
  endtask

  // ========================================================================
  initial begin
    if ($test$plusargs("vcd")) begin $dumpfile("mini_risc_tb.vcd"); $dumpvars(1, mini_risc_tb); $dumpvars(2, dut); end
    init_tables;
    nrand_run = N_RANDOM; nomulu = $test$plusargs("nomulu");
    if ($test$plusargs("quick")) begin ncv = 7; nrand_run = 60; end
    if ($value$plusargs("nrand=%d", nrand_run)) ;
    if ($value$plusargs("ncv=%d", ncv)) ;
    #1;
    if ($test$plusargs("prof")) begin repeat (20) t_smoke; $display("done"); $finish; end
    t_smoke;
    t_control;
    t_halt_nop_illegal;
    t_rtype_hand;
    t_itype_hand;
    t_rtype_corners;
    t_itype_corners;
    t_regfile;
    t_constants;
    t_mul;
    t_memory;
    t_branches;
    t_jumps;
    t_programs;
    t_random;

    $display("\n--------------------------------------------------------------");
    $display(" programs run: %0d    ISS-checked instructions: %0d", n_progs, n_instr_checked);
    $display(" checks passed: %0d    checks FAILED: %0d", n_pass, n_fail);
    if (n_fail == 0) $display(" *** ALL TESTS PASSED ***");
    else             $display(" *** %0d CHECK(S) FAILED ***", n_fail);
    $display("--------------------------------------------------------------");
    $finish;
  end

  // global watchdog
  initial begin
    #2_000_000_000;
    $display("GLOBAL WATCHDOG EXPIRED");
    $finish;
  end
endmodule
