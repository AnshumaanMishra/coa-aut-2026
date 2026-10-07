`timescale 1ns/1ps
module tb_mux_4to1;
  reg  [31:0] i0, i1, i2, i3;
  reg  [4:0]  j0, j1, j2, j3;
  reg  [1:0]  sel;
  wire [31:0] o;
  wire [4:0]  o5;

  mux_4to1 #(.WIDTH(32)) dut  (.I0(i0), .I1(i1), .I2(i2), .I3(i3), .sel(sel), .O(o));
  mux_4to1 #(.WIDTH(5))  dut5 (.I0(j0), .I1(j1), .I2(j2), .I3(j3), .sel(sel), .O(o5));

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
  integer n, seed;
  reg [31:0] exp32;
  reg [4:0]  exp5;

  initial begin
    seed = 11;

    // distinct constants so a wrong wiring shows up right away
    i0 = 32'h00000011; i1 = 32'h00002222; i2 = 32'h00333333; i3 = 32'h44444444;
    j0 = 5'd1; j1 = 5'd2; j2 = 5'd4; j3 = 5'd8;

    for (n = 0; n < 4; n = n + 1) begin
      sel = n; #1;
      case (n)
        0: begin exp32 = i0; exp5 = j0; end
        1: begin exp32 = i1; exp5 = j1; end
        2: begin exp32 = i2; exp5 = j2; end
        default: begin exp32 = i3; exp5 = j3; end
      endcase
      check(o,  exp32, "fixed inputs, 32 bit");
      check(o5, exp5,  "fixed inputs, 5 bit");
    end

    for (n = 0; n < 400; n = n + 1) begin
      i0 = $random(seed); i1 = $random(seed); i2 = $random(seed); i3 = $random(seed);
      j0 = $random(seed); j1 = $random(seed); j2 = $random(seed); j3 = $random(seed);
      sel = $random(seed);
      #1;
      case (sel)
        2'd0: begin exp32 = i0; exp5 = j0; end
        2'd1: begin exp32 = i1; exp5 = j1; end
        2'd2: begin exp32 = i2; exp5 = j2; end
        2'd3: begin exp32 = i3; exp5 = j3; end
      endcase
      check(o,  exp32, "random, 32 bit");
      check(o5, exp5,  "random, 5 bit");
    end

    if (errors == 0) $display("tb_mux_4to1: all %0d checks passed", checks);
    else             $display("tb_mux_4to1: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
