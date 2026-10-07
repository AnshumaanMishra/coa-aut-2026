`timescale 1ns/1ps
module tb_register_file;
  reg         clk, reg_write, hi_lo_enable;
  reg  [4:0]  rs, rt, rd;
  reg  [31:0] reg_in_hi, reg_in_lo;
  wire [31:0] rs_out, rt_out;

  register_file dut (
    .clk(clk), .reg_write(reg_write), .hi_lo_enable(hi_lo_enable),
    .rs(rs), .rt(rt), .rd(rd),
    .reg_in_hi(reg_in_hi), .reg_in_lo(reg_in_lo),
    .rs_out(rs_out), .rt_out(rt_out));

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
  // simple software copy of what the register file should hold
  reg [31:0] gpr [0:15];
  reg [31:0] m_hi, m_lo;
  integer i, a, seed;

  task model_write;
    input we, hl;
    input [4:0] d;
    input [31:0] hi_v, lo_v;
    begin
      if (we) begin
        if (hl) begin
          m_hi = hi_v;
          m_lo = lo_v;
        end else if (d[4] == 0 && d[3:0] != 0)
          gpr[d[3:0]] = lo_v;
      end
    end
  endtask

  // one clock cycle with the given write controls, model updated alongside
  task cycle;
    input we, hl;
    input [4:0] d;
    input [31:0] hi_v, lo_v;
    begin
      reg_write = we; hi_lo_enable = hl; rd = d;
      reg_in_hi = hi_v; reg_in_lo = lo_v;
      @(posedge clk); #1;
      model_write(we, hl, d, hi_v, lo_v);
      reg_write = 0; hi_lo_enable = 0;
    end
  endtask

  // read every address on both ports and compare with the model
  task sweep;
    reg [31:0] e_rs, e_rt;
    begin
      for (a = 0; a < 32; a = a + 1) begin
        rs = a; rt = a;
        #1;
        // rs port: R0..R15 only, anything with bit 4 set reads zero
        e_rs = (a < 16 && a != 0) ? gpr[a] : 32'h0;
        // rt port: same, but 10000 and 10001 reach HI and LO
        if (a < 16)       e_rt = (a == 0) ? 32'h0 : gpr[a];
        else if (a == 16) e_rt = m_hi;
        else if (a == 17) e_rt = m_lo;
        else              e_rt = 32'h0;
        check(rs_out, e_rs, "rs port");
        check(rt_out, e_rt, "rt port");
      end
    end
  endtask

  initial begin
    seed = 181;
    for (i = 0; i < 16; i = i + 1) gpr[i] = 0;
    m_hi = 0; m_lo = 0;
    reg_write = 0; hi_lo_enable = 0;
    rs = 0; rt = 0; rd = 0; reg_in_hi = 0; reg_in_lo = 0;
    @(posedge clk); #1;

    // everything starts at zero
    sweep;

    // give each register its own value
    for (i = 1; i < 16; i = i + 1)
      cycle(1, 0, i, 32'h0, 32'h01010101 * i);
    sweep;

    // writes to R0 are thrown away
    cycle(1, 0, 5'd0, 32'h0, 32'hFFFFFFFF);
    rs = 0; rt = 0; #1;
    check(rs_out, 0, "R0 on rs after write");
    check(rt_out, 0, "R0 on rt after write");

    // reg_write low means no write
    cycle(0, 0, 5'd3, 32'h0, 32'hBADBADBA);
    sweep;

    // rd with bit 4 set and no hi_lo_enable must not touch any GPR
    cycle(1, 0, 5'b10011, 32'h0, 32'h12121212);
    cycle(1, 0, 5'b11111, 32'h0, 32'h34343434);
    sweep;

    // HI/LO write: reaches hi and lo, not the GPR named by rd
    cycle(1, 1, 5'b10001, 32'hAAAA0001, 32'hBBBB0002);
    sweep;
    cycle(1, 1, 5'd7, 32'hCAFE0003, 32'hF00D0004);
    sweep;
    rs = 7; #1;
    check(rs_out, 32'h07070707, "R7 not clobbered by hi/lo write");

    // hi_lo_enable with reg_write low does nothing
    cycle(0, 1, 5'b10001, 32'h11111111, 32'h22222222);
    sweep;

    // no bypass: reading the register being written still shows the old value
    // until the clock edge
    rs = 5'd4; reg_write = 1; hi_lo_enable = 0; rd = 5'd4; reg_in_lo = 32'hA5A5A5A5;
    #1;
    check(rs_out, gpr[4], "no write-through before edge");
    @(posedge clk); #1;
    model_write(1, 0, 5'd4, 32'h0, 32'hA5A5A5A5);
    reg_write = 0;
    check(rs_out, 32'hA5A5A5A5, "new value after edge");

    // read ports are combinational: change address, output follows
    rs = 5'd2; rt = 5'd9; #1;
    check(rs_out, gpr[2], "rs follows address");
    check(rt_out, gpr[9], "rt follows address");
    rs = 5'd10; rt = 5'd11; #1;
    check(rs_out, gpr[10], "rs follows address again");
    check(rt_out, gpr[11], "rt follows address again");

    // random traffic
    for (i = 0; i < 1500; i = i + 1) begin
      cycle($random(seed), $random(seed), $random(seed), $random(seed), $random(seed));
      if (i % 50 == 0) sweep;
    end
    sweep;

    if (errors == 0) $display("tb_register_file: all %0d checks passed", checks);
    else             $display("tb_register_file: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
