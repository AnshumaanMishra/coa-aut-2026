module register(clk, data_in, load, data_out);
  input [31:0] data_in;
  input clk, load;
  output reg [31:0] data_out;

  initial begin
    data_out = 32'b0;
  end

  always @(posedge clk) begin
    if(load) begin
      data_out <= data_in;
    end
  end

endmodule
