`timescale 1ns/1ps
module tb_next_address_decoder;
  reg  [31:0] rs, rt, pc;
  reg  [25:0] jta;
  reg         le, lt, gt, ge, ne, eq, ovfl;
  reg  [2:0]  br_type;
  reg         is_branch;
  reg  [1:0]  pc_src;
  wire [31:0] incr_pc, next_pc;

  next_address_decoder dut (
    .rt(rt), .rs(rs), .jta(jta), .pc(pc),
    .le(le), .lt(lt), .gt(gt), .ge(ge), .ne(ne), .eq(eq), .ovfl(ovfl),
    .br_type(br_type), .is_branch(is_branch), .pc_src(pc_src),
    .incr_pc(incr_pc), .next_pc(next_pc));

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
  // br_type codes from the control word table
  localparam [2:0] B_EQ = 3'b001, B_NE = 3'b010, B_LT = 3'b011, B_LE = 3'b100,
                   B_GT = 3'b101, B_GE = 3'b110, B_OV = 3'b111;

  integer i, a, b, t, seed;
  reg        taken;
  reg [31:0] off, e_incr, e_next;
  reg [29:0] w;

  // flags as the ALU would produce them for x = a, y = b
  task set_flags;
    input integer av, bv;
    begin
      lt = (av <  bv);
      gt = (av >  bv);
      le = (av <= bv);
      ge = (av >= bv);
      eq = (av == bv);
      ne = (av != bv);
    end
  endtask

  // apply current inputs, work out the expected answer and compare
  task evaluate;
    input [127:0] what;
    begin
      #1;
      case (br_type)
        B_EQ: taken = eq;
        B_NE: taken = ne;
        B_LT: taken = lt;
        B_LE: taken = le;
        B_GT: taken = gt;
        B_GE: taken = ge;
        B_OV: taken = ovfl;
        default: taken = 0;
      endcase
      taken = taken & is_branch;

      off = {{16{jta[15]}}, jta[15:0]};
      w = pc[31:2] + 30'd1 + (taken ? off[29:0] : 30'd0);
      e_incr = {w, 2'b00};

      case (pc_src)
        2'd0: e_next = e_incr;
        2'd1: e_next = {e_incr[31:28], jta, 2'b00};
        2'd2: e_next = {rs[31:2], 2'b00};
        2'd3: e_next = 32'h0;
      endcase

      check(incr_pc, e_incr, what);
      check(next_pc, e_next, what);
    end
  endtask

  initial begin
    seed = 191;
    rt = 0; ovfl = 0; rs = 32'h0; jta = 0;
    set_flags(0, 0);
    br_type = 0; is_branch = 0; pc_src = 0; pc = 32'h100;

    // plain sequential fetch
    evaluate("pc + 4");
    check(next_pc, 32'h104, "sequential next_pc");
    check(incr_pc, 32'h104, "sequential incr_pc");

    // taken branch, forward 3 words: target = pc + 4 + 12
    jta = 26'h0000003; is_branch = 1; br_type = B_EQ; set_flags(4, 4);
    evaluate("BEQ taken +3");
    check(next_pc, 32'h110, "BEQ taken target");

    // backward branch, -2 words: pc + 4 - 8
    jta = 26'h000FFFE; evaluate("BEQ taken -2");
    check(next_pc, 32'h0FC, "backward target");

    // same instruction, condition false
    set_flags(4, 5);
    evaluate("BEQ not taken");
    check(next_pc, 32'h104, "BEQ not taken falls through");

    // is_branch low: flags and br_type are ignored
    is_branch = 0; br_type = B_EQ; set_flags(1, 1);
    evaluate("flags ignored without is_branch");
    check(next_pc, 32'h104, "no branch when is_branch=0");

    // every branch type against less / equal / greater
    is_branch = 1; jta = 26'h0000005;
    for (t = 1; t < 8; t = t + 1) begin
      br_type = t;
      for (a = -1; a <= 1; a = a + 1) begin
        set_flags(a, 0);
        ovfl = 0;
        evaluate("branch type sweep");
      end
    end
    // BV looks only at ovfl
    br_type = B_OV; set_flags(0, 0);
    ovfl = 1; evaluate("BV taken");
    check(next_pc, 32'h100 + 4 + 20, "BV taken target");
    ovfl = 0; evaluate("BV not taken");
    check(next_pc, 32'h104, "BV not taken");
    ovfl = 0;

    // jump: upper 4 bits of the word address come from pc + 4
    is_branch = 0; pc_src = 2'd1; jta = 26'h0000010;
    evaluate("J");
    check(next_pc, 32'h40, "J to word 0x10");

    pc = 32'h30000100; jta = 26'h0123456;
    evaluate("J keeps pc upper bits");
    check(next_pc, {4'h3, 26'h0123456, 2'b00}, "J with upper bits");

    // JAL needs incr_pc to be the plain pc + 4 even though pc_src picks jta
    pc = 32'h00000200; jta = 26'h0000040; br_type = B_EQ; set_flags(0, 0);
    evaluate("JAL link");
    check(incr_pc, 32'h204, "link address");

    // JR: register value, low two bits dropped
    pc_src = 2'd2; rs = 32'h00000124; evaluate("JR aligned");
    check(next_pc, 32'h124, "JR target");
    rs = 32'h00000127; evaluate("JR low bits");
    check(next_pc, 32'h124, "JR ignores low bits");

    // start up: forced to zero
    pc_src = 2'd3; pc = 32'h00000ABC; evaluate("start");
    check(next_pc, 32'h0, "pc_src 11 gives zero");

    // random
    for (i = 0; i < 3000; i = i + 1) begin
      pc = {$random(seed)} & 32'h0FFFFFFC;
      rs = $random(seed);
      rt = $random(seed);
      jta = $random(seed);
      a = $random(seed) % 5;
      b = $random(seed) % 5;
      set_flags(a, b);
      ovfl = $random(seed);
      br_type = $random(seed);
      if (br_type == 0) br_type = B_EQ;
      is_branch = $random(seed);
      pc_src = $random(seed);
      evaluate("random");
    end

    if (errors == 0) $display("tb_next_address_decoder: all %0d checks passed", checks);
    else             $display("tb_next_address_decoder: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
