`timescale 1ns/1ps
// Compile with -g2012 (DUT uses `reg [31:0] registers[16];`)
module register_file_tb;
  reg         clk = 0;
  reg         reg_write = 0, hi_lo_enable = 0;
  reg  [4:0]  rs = 0, rt = 0, rd = 0;
  reg  [31:0] reg_in_hi = 0, reg_in_lo = 0;
  wire [31:0] rs_out, rt_out;

  reg [31:0] m_regs [0:15];
  reg [31:0] m_hi, m_lo;
  integer errors = 0;
  integer i;

  register_file dut (
    .clk(clk), .reg_write(reg_write), .hi_lo_enable(hi_lo_enable),
    .rs(rs), .rt(rt), .rd(rd),
    .reg_in_hi(reg_in_hi), .reg_in_lo(reg_in_lo),
    .rs_out(rs_out), .rt_out(rt_out)
  );

  always #5 clk = ~clk;

  function [31:0] exp_rs(input [4:0] a);
    exp_rs = (a[4] == 0 && a[3:0] != 0) ? m_regs[a[3:0]] : 32'b0;
  endfunction

  function [31:0] exp_rt(input [4:0] a);
    begin
      if (a[4] == 0) exp_rt = (a[3:0] != 0) ? m_regs[a[3:0]] : 32'b0;
      else if (a[3:0] == 4'd0) exp_rt = m_hi;
      else if (a[3:0] == 4'd1) exp_rt = m_lo;
      else exp_rt = 32'b0;
    end
  endfunction

  task check_reads(input [8*40-1:0] msg);
    begin
      if (rs_out !== exp_rs(rs)) begin
        errors = errors + 1;
        $display("FAIL [%0t] %0s: rs=%0d rs_out=%h exp=%h", $time, msg, rs, rs_out, exp_rs(rs));
      end
      if (rt_out !== exp_rt(rt)) begin
        errors = errors + 1;
        $display("FAIL [%0t] %0s: rt=%0d rt_out=%h exp=%h", $time, msg, rt, rt_out, exp_rt(rt));
      end
    end
  endtask

  task cycle(input we, input hl, input [4:0] a_rd, input [4:0] a_rs, input [4:0] a_rt,
             input [31:0] hi_in, input [31:0] lo_in, input [8*40-1:0] msg);
    begin
      @(negedge clk);
      reg_write = we; hi_lo_enable = hl; rd = a_rd; rs = a_rs; rt = a_rt;
      reg_in_hi = hi_in; reg_in_lo = lo_in;
      #1 check_reads(msg);                 // combinational reads, pre-edge state
      @(posedge clk);
      if (we) begin
        if (hl) begin m_hi = hi_in; m_lo = lo_in; end
        else if (a_rd[4] == 0 && a_rd[3:0] != 0) m_regs[a_rd[3:0]] = lo_in;
      end
      #1 check_reads(msg);                 // post-edge state
    end
  endtask

  initial begin
    for (i = 0; i < 16; i = i + 1) m_regs[i] = 0;
    m_hi = 0; m_lo = 0;

    // 1. everything reads zero after init
    #1;
    for (i = 0; i < 32; i = i + 1) begin
      rs = i; rt = i; #1;
      check_reads("reset state");
    end

    // 2. write and read every general register 1..15
    for (i = 1; i < 16; i = i + 1)
      cycle(1, 0, i, i, i, 32'h0, 32'hA000_0000 + i, "write r1..r15");

    // 3. r0 hardwired to zero
    cycle(1, 0, 5'd0, 5'd0, 5'd0, 32'h0, 32'hFFFF_FFFF, "write r0 ignored");

    // 4. rd[4]=1 must not write a GPR
    for (i = 16; i < 32; i = i + 1)
      cycle(1, 0, i[4:0], 5'd1, 5'd2, 32'h0, 32'h1111_1111, "write rd[4]=1 ignored");

    // 5. reg_write=0 blocks writes
    cycle(0, 0, 5'd3, 5'd3, 5'd3, 32'h0, 32'hBAD0_BAD0, "reg_write=0 blocks gpr write");
    cycle(0, 1, 5'd3, 5'd0, 5'd16, 32'hBAD1_BAD1, 32'hBAD2_BAD2, "reg_write=0 blocks hi/lo");

    // 6. hi/lo write and read through rt[4]=1
    cycle(1, 1, 5'd0, 5'd0, 5'd16, 32'hABCD_0001, 32'h1234_0002, "hi/lo write, rt=hi");
    cycle(0, 0, 5'd0, 5'd0, 5'd17, 32'h0, 32'h0, "rt=lo");
    cycle(0, 0, 5'd0, 5'd0, 5'd18, 32'h0, 32'h0, "rt=18 -> 0");
    cycle(0, 0, 5'd0, 5'd0, 5'd31, 32'h0, 32'h0, "rt=31 -> 0");

    // 7. hi_lo_enable must not touch GPRs
    cycle(1, 1, 5'd7, 5'd7, 5'd7, 32'h5555_5555, 32'hAAAA_AAAA, "hilo write leaves r7");

    // 8. rs with bit4 set returns 0
    cycle(0, 0, 5'd0, 5'd16, 5'd0, 32'h0, 32'h0, "rs=16 -> 0");
    cycle(0, 0, 5'd0, 5'd17, 5'd0, 32'h0, 32'h0, "rs=17 -> 0");
    cycle(0, 0, 5'd0, 5'd21, 5'd0, 32'h0, 32'h0, "rs=21 -> 0");

    // 9. write + read same register
    cycle(1, 0, 5'd9, 5'd9, 5'd9, 32'h0, 32'hC0DE_C0DE, "write/read same reg");

    // 10. randomized
    for (i = 0; i < 5000; i = i + 1)
      cycle($urandom_range(0,1), ($urandom_range(0,3) == 0),
            $urandom, $urandom, $urandom, $urandom, $urandom, "random");

    if (errors == 0) $display("register_file_tb: PASS");
    else             $display("register_file_tb: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
