module register(clk, data, read, clear, out);
  input [3:0] data;
  input clk, read, clear; // read = R/W'
  output reg [3:0] out;

  always @(posedge clk) begin
    if(clear) begin
      out = 4'b0000;
    end
    else if(!read) begin
      out = data;
    end
  end
endmodule

module register_test;
  reg [3:0] input_data;
  wire [3:0] output_data;
  reg clk, read, clear;

  register r1(
    .clk(clk),
    .data(input_data),
    .read(read),
    .clear(clear),
    .out(output_data)
  );

  always begin
    #5 clk = ~clk;
  end

  initial begin
    clk = 0;
    input_data = 4'b0000; read = 0; clear = 1; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b0001; read = 0; clear = 1; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b0001; read = 0; clear = 0; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b0011; read = 0; clear = 0; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b0101; read = 1; clear = 0; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b1001; read = 0; clear = 1; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    input_data = 4'b0111; read = 0; clear = 0; #10;
    $display("Input: %b; Output: %b", input_data, output_data);
    $finish;
  end
endmodule
