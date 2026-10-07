`timescale 1ns/1ps
module tb_mux_8to1;
  reg  [31:0] d [0:7];
  reg  [2:0]  sel;
  wire [31:0] o;
  reg  [4:0]  e [0:7];
  wire [4:0]  o5;
  wire        o1;

  mux_8to1 #(.WIDTH(32)) dut (
    .I0(d[0]), .I1(d[1]), .I2(d[2]), .I3(d[3]),
    .I4(d[4]), .I5(d[5]), .I6(d[6]), .I7(d[7]),
    .sel(sel), .O(o));

  // 5 bit version is the one the data path uses for rt_sel
  mux_8to1 #(.WIDTH(5)) dut5 (
    .I0(e[0]), .I1(e[1]), .I2(e[2]), .I3(e[3]),
    .I4(e[4]), .I5(e[5]), .I6(e[6]), .I7(e[7]),
    .sel(sel), .O(o5));

  // 1 bit version (overflow mux in the ALU): only input 2 is ever non-zero there
  mux_8to1 #(.WIDTH(1)) dut1 (
    .I0(1'b0), .I1(1'b0), .I2(d[0][0]), .I3(1'b0),
    .I4(1'b0), .I5(1'b0), .I6(1'b0), .I7(1'b0),
    .sel(sel), .O(o1));

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
  integer n, k, seed;

  initial begin
    seed = 3;

    for (k = 0; k < 8; k = k + 1) begin
      d[k] = (32'h1 << (k * 4)) | k;
      e[k] = 5'd3 * k + 1;
    end

    for (n = 0; n < 8; n = n + 1) begin
      sel = n; #1;
      check(o,  d[n], "fixed pattern 32 bit");
      check(o5, e[n], "fixed pattern 5 bit");
    end

    // 1 bit mux, make the single live input 1 and walk sel
    d[0] = 32'h1;
    for (n = 0; n < 8; n = n + 1) begin
      sel = n; #1;
      check(o1, (n == 2), "1 bit mux");
    end

    for (n = 0; n < 500; n = n + 1) begin
      for (k = 0; k < 8; k = k + 1) begin
        d[k] = $random(seed);
        e[k] = $random(seed);
      end
      sel = $random(seed);
      #1;
      check(o,  d[sel], "random 32 bit");
      check(o5, e[sel], "random 5 bit");
    end

    if (errors == 0) $display("tb_mux_8to1: all %0d checks passed", checks);
    else             $display("tb_mux_8to1: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
