`timescale 1ns/1ps
module tb_data_cache;
  reg         clk;
  reg  [31:0] address, data_input;
  reg         read, write;
  wire [31:0] data_out;

  data_cache dut (
    .clk(clk), .address(address), .data_input(data_input),
    .read(read), .write(write), .data_out(data_out));

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
  integer i;
  reg [31:0] pattern;

  // inputs change just after the clock edge so they are stable at the next one
  task write_word;
    input [31:0] a, d;
    begin
      address = a; data_input = d; write = 1; read = 0;
      @(posedge clk); #1;
      write = 0;
    end
  endtask

  task read_word;
    input [31:0] a;
    begin
      address = a; read = 1; write = 0;
      @(posedge clk); #1;
      read = 0;
    end
  endtask

  initial begin
    address = 0; data_input = 0; read = 0; write = 0;
    @(posedge clk); #1;

    // basic store then load
    write_word(32'h00000010, 32'hDEADBEEF);
    read_word(32'h00000010);
    check(data_out, 32'hDEADBEEF, "read back after write");

    // neighbouring words stay separate
    write_word(32'h00000014, 32'h11112222);
    write_word(32'h0000000C, 32'h33334444);
    read_word(32'h00000010);
    check(data_out, 32'hDEADBEEF, "word 4 untouched by neighbours");
    read_word(32'h00000014);
    check(data_out, 32'h11112222, "word 5");
    read_word(32'h0000000C);
    check(data_out, 32'h33334444, "word 3");

    // byte offset bits are dropped (word access only)
    read_word(32'h00000012);
    check(data_out, 32'hDEADBEEF, "address 0x12 hits word 4");
    write_word(32'h00000013, 32'hCAFEF00D);
    read_word(32'h00000010);
    check(data_out, 32'hCAFEF00D, "write to 0x13 lands in word 4");

    // only address[11:2] goes to the RAM, so 4KB aliasing is expected
    read_word(32'h00001014);
    check(data_out, 32'h11112222, "0x1014 aliases 0x14");

    // a read must not modify memory even if data_input is changing
    data_input = 32'hFFFFFFFF;
    read_word(32'h00000014);
    read_word(32'h00000014);
    check(data_out, 32'h11112222, "read leaves memory alone");

    // with read and write both low nothing is stored
    address = 32'h00000014; data_input = 32'h0BADF00D; read = 0; write = 0;
    @(posedge clk); #1;
    read_word(32'h00000014);
    check(data_out, 32'h11112222, "idle cycle does not write");

    // data_out has to hold when idle, the LD commit cycle depends on it
    read_word(32'h00000010);
    address = 32'h0000000C; read = 0; write = 0;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(data_out, 32'hCAFEF00D, "data_out holds while idle");

    // fill the whole 1024 words and read them all back
    for (i = 0; i < 1024; i = i + 1) begin
      pattern = (i * 32'h9E3779B1) ^ 32'h5A5A0000;
      write_word(i * 4, pattern);
    end
    for (i = 0; i < 1024; i = i + 1) begin
      read_word(i * 4);
      pattern = (i * 32'h9E3779B1) ^ 32'h5A5A0000;
      check(data_out, pattern, "full sweep");
    end

    if (errors == 0) $display("tb_data_cache: all %0d checks passed", checks);
    else             $display("tb_data_cache: %0d of %0d checks FAILED", errors, checks);
    $finish;
  end
endmodule
