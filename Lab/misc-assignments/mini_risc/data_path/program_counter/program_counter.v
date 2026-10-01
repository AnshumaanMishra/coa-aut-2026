module program_counter(clk, next_pc, pc_write_en, pc_out);
  input [31:0] next_pc;
  input clk, pc_write_en;
  output reg [31:0] pc_out;

  initial begin
    pc_out = 32'b0;
  end

  always @(posedge clk) begin
    if(pc_write_en) begin
      pc_out <= next_pc;
    end
  end

endmodule
