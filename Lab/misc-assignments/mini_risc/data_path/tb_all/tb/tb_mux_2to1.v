`timescale 1ns/1ps
module tb_mux_2to1;
  reg  [31:0] a, b;
  reg  [4:0]  a5, b5;
  reg         s;
  wire [31:0] o;
  wire [4:0]  o5;

  mux_2to1 #(.WIDTH(32)) dut   (.I0(a),  .I1(b),  .sel(s), .O(o));
  mux_2to1 #(.WIDTH(5))  dut5  (.I0(a5), .I1(b5), .sel(s), .O(o5));

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
  integer i, seed;

  initial begin
    seed = 7;

    a = 32'hAAAA5555; b = 32'h12345678; a5 = 5'b10101; b5 = 5'b01010;
    s = 0; #1;
    check(o, a, "sel=0 picks I0");
    check(o5, a5, "5 bit sel=0");
    s = 1; #1;
    check(o, b, "sel=1 picks I1");
    check(o5, b5, "5 bit sel=1");

    // changing the unselected input should not matter
    b = 32'hFFFFFFFF; #1;
    check(o, 32'hFFFFFFFF, "follows I1 when sel=1");
    s = 0; b = 32'h0; #1;
    check(o, a, "ignores I1 when sel=0");

    for (i = 0; i < 500; i = i + 1) begin
      a = $random(seed); b = $random(seed);
      a5 = $random(seed); b5 = $random(seed);
      s = $random(seed);
      #1;
      check(o,  s ? b  : a,  "random 32 bit");
      check(o5, s ? b5 : a5, "random 5 bit");
    end

    if (errors == 0) $display("tb_mux_2to1: all %0d checks passed", checks);
    else             $display("tb_mux_2to1: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
