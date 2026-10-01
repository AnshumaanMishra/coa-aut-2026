module register(clk, data, read, out);
  input clk, read;
  input [7:0] data;
  output reg [7:0] out;

  always @(posedge clk) begin
    if(~read) begin
      out <= data;
    end
  end

endmodule
