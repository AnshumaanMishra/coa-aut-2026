`timescale 1ns/1ps
module next_address_decoder_tb;
  reg  [31:0] rs = 0, rt = 0, pc = 0;
  reg  [25:0] jta = 0;
  reg         le = 0, lt = 0, gt = 0, ge = 0, ne = 0, eq = 0, ovfl = 0;
  reg  [2:0]  br_type = 0;
  reg         is_branch = 0;
  reg  [1:0]  pc_src = 0;
  wire [31:0] incr_pc, next_pc;

  integer errors = 0, i, t;

  next_address_decoder dut (
    .rt(rt), .rs(rs), .jta(jta), .pc(pc),
    .le(le), .lt(lt), .gt(gt), .ge(ge), .ne(ne), .eq(eq), .ovfl(ovfl),
    .br_type(br_type), .is_branch(is_branch), .pc_src(pc_src),
    .incr_pc(incr_pc), .next_pc(next_pc)
  );

  function cond_sel(input [2:0] ty);
    case (ty)
      3'd0: cond_sel = 1'b1;
      3'd1: cond_sel = eq;
      3'd2: cond_sel = ne;
      3'd3: cond_sel = lt;
      3'd4: cond_sel = le;
      3'd5: cond_sel = gt;
      3'd6: cond_sel = ge;
      default: cond_sel = ovfl;
    endcase
  endfunction

  reg        m_br;
  reg [29:0] m_inc;
  reg [31:0] m_incr_pc, m_next_pc;

  task compute_model;
    begin
      m_br  = cond_sel(br_type) & is_branch;
      m_inc = pc[31:2] + 30'd1 + (m_br ? {{14{jta[15]}}, jta[15:0]} : 30'd0);
      m_incr_pc = {m_inc, 2'b00};
      case (pc_src)
        2'd0: m_next_pc = {m_inc, 2'b00};
        2'd1: m_next_pc = {m_inc[29:26], jta, 2'b00};
        2'd2: m_next_pc = {rs[31:2], 2'b00};
        2'd3: m_next_pc = 32'b0;
      endcase
    end
  endtask

  task check(input [8*40-1:0] msg);
    begin
      #1; compute_model;
      if (incr_pc !== m_incr_pc) begin
        errors = errors + 1;
        $display("FAIL %0s: incr_pc=%h exp=%h (pc=%h jta=%h br_type=%0d is_br=%b)",
                 msg, incr_pc, m_incr_pc, pc, jta, br_type, is_branch);
      end
      if (next_pc !== m_next_pc) begin
        errors = errors + 1;
        $display("FAIL %0s: next_pc=%h exp=%h (pc=%h jta=%h pc_src=%0d)",
                 msg, next_pc, m_next_pc, pc, jta, pc_src);
      end
    end
  endtask

  task set_flags(input [6:0] f); // {le,lt,gt,ge,ne,eq,ovfl}
    {le, lt, gt, ge, ne, eq, ovfl} = f;
  endtask

  initial begin
    // sequential: PC + 4
    pc = 32'h0000_0000; is_branch = 0; pc_src = 0; check("pc+4 from 0");
    pc = 32'h0000_1000; check("pc+4 from 0x1000");
    pc = 32'hFFFF_FFFC; check("pc+4 wraparound");

    // taken branches, positive/negative offsets
    is_branch = 1; br_type = 3'd0;
    pc = 32'h0000_0100; jta = 26'd3;       check("br uncond +3");
    if (incr_pc !== 32'h0000_0110) begin errors = errors + 1; $display("FAIL literal: +3 -> %h", incr_pc); end
    jta = 26'h3FFFFFF;                     check("br uncond -1");
    jta = {10'b0, 16'h8000};               check("br uncond most negative");
    jta = {10'b0, 16'h7FFF};               check("br uncond most positive");
    jta = {10'h3FF, 16'h0005};             check("upper jta bits ignored by offset");

    // each br_type, taken vs not taken
    jta = 26'd10; pc = 32'h0000_0200;
    for (t = 0; t < 8; t = t + 1) begin
      br_type = t;
      set_flags(7'b0000000); check("br_type, all flags 0");
      set_flags(7'b1111111); check("br_type, all flags 1");
      for (i = 0; i < 128; i = i + 1) begin set_flags(i[6:0]); check("br_type, flag sweep"); end
    end
    // is_branch=0 suppresses every condition
    is_branch = 0;
    for (t = 0; t < 8; t = t + 1) begin
      br_type = t; set_flags(7'b1111111); check("is_branch=0 suppresses");
    end
    is_branch = 1;

    // pc_src selection
    set_flags(7'b0); br_type = 0; is_branch = 0;
    pc = 32'h4000_0010; jta = 26'h155_AAAA; rs = 32'hDEAD_BEE7;
    pc_src = 0; check("pc_src=0 sequential");
    pc_src = 1; check("pc_src=1 jump");
    pc_src = 2; check("pc_src=2 register");
    pc_src = 3; check("pc_src=3 syscall -> 0");
    pc = 32'h0FFF_FFFC; pc_src = 1; check("jump at region boundary");
    is_branch = 1; br_type = 0; jta = 26'h0000_0001; pc = 32'h0FFF_FFF8; pc_src = 1;
    check("jump with branch adder active");

    // randomized
    for (i = 0; i < 20000; i = i + 1) begin
      pc = $urandom; rs = $urandom; rt = $urandom; jta = $urandom;
      set_flags($urandom); br_type = $urandom; is_branch = $urandom; pc_src = $urandom;
      check("random");
    end

    if (errors == 0) $display("next_address_decoder_tb: PASS");
    else             $display("next_address_decoder_tb: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
