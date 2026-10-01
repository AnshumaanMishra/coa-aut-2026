module tb_fib;

  reg clk;
  reg reset;
  reg start;
  reg [7:0] K;

  wire [7:0] O;

  fibonacci dut (
      .clk(clk),
      .reset(reset),
      .start(start),
      .K(K),
      .O(O)
  );

  always #5 clk = ~clk;

  initial begin
    clk   = 0;
    reset = 1;
    start = 0;
    K     = 12;

    #7;
    reset = 0;
    start = 1;

    // #10;
    // start = 0;

    #280;

    $display("FINAL: F(%d) = %d", K, O);
    $finish;
  end

  always @(posedge clk) begin
    #1;
    $display("t=%0t state=%b | Kreg=%b F0=%b F1=%b A=%b | gt=%b | sel=%b%b%b ld=%b%b%b%b", $time,
             dut.cp.current_state, dut.dp.K_out, dut.dp.f0_out, dut.dp.f1_out, dut.dp.A_out,
             dut.dp.gt, dut.dp.sel0, dut.dp.sel1, dut.dp.selK, dut.dp.ld0, dut.dp.ld1, dut.dp.ldK,
             dut.dp.ldA);
  end

endmodule


















