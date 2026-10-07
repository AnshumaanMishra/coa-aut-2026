`timescale 1ns/1ps
module register_tb;
  reg clk = 0, load = 0;
  reg [31:0] data_in = 0;
  wire [31:0] data_out;
  reg [31:0] model = 0;
  integer errors = 0, i;

  register dut (.clk(clk), .data_in(data_in), .load(load), .data_out(data_out));
  always #5 clk = ~clk;

  task check(input [8*24-1:0] msg);
    if (data_out !== model) begin
      errors = errors + 1;
      $display("FAIL [%0t] %0s: data_out=%h exp=%h", $time, msg, data_out, model);
    end
  endtask

  initial begin
    #1 check("initial zero");
    for (i = 0; i < 500; i = i + 1) begin
      @(negedge clk);
      load = $urandom_range(0,1);
      data_in = $urandom;
      @(posedge clk);
      if (load) model = data_in;
      #1 check("random load/hold");
    end
    @(negedge clk); load = 1; data_in = 32'h1357_9BDF;
    @(posedge clk); model = data_in; #1 check("load");
    #2 data_in = 32'hFFFF_FFFF; #1 check("data_in glitch ignored");

    if (errors == 0) $display("register_tb: PASS");
    else             $display("register_tb: FAIL (%0d errors)", errors);
    $finish;
  end
endmodule
