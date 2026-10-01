`timescale 1ns / 1ps

module bram_ram_rom_practice_tb;

  reg clk;
  reg reset;
  reg start;
  wire done;
  wire [31:0] result_out;

  // ---- DUT instantiation ----
  bram_ram_rom_practice dut (
      .clk       (clk),
      .reset     (reset),
      .start     (start),
      .done      (done),
      .result_out(result_out)
  );

  // ---- Clock generation: 10ns period (100MHz) ----
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---- Waveform dump ----
  initial begin
    $dumpfile("bram_ram_rom_practice_tb.vcd");
    $dumpvars(0, bram_ram_rom_practice_tb);
  end

  // ---- Stimulus ----
  initial begin
    // 1. Apply reset
    reset = 1'b1;
    start = 1'b0;
    @(posedge clk);
    @(posedge clk);

    // 2. Release reset
    reset = 1'b0;
    @(posedge clk);

    // 3. Pulse start for one clock edge
    start = 1'b1;
    @(posedge clk);
    start = 1'b0;

    // 4. Wait until done = 1 (with a safety timeout so a bug doesn't hang forever)
    fork
      begin
        wait (done == 1'b1);
      end
      begin
        #10000;
        $display("FAIL: timeout waiting for done (possible FSM lockup)");
        $finish;
      end
    join_any
    disable fork;

    // 5. Check result
    if (result_out == 32'h00000168) $display("PASS: result_out = %h, done = %b", result_out, done);
    else $display("FAIL: result = %h (expected 00000168)", result_out);

    // 6. Terminate
    $finish;
  end

endmodule
