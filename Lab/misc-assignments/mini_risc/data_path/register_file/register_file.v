module register_file (
    clk,
    reg_write,
    hi_lo_enable,
    rs,
    rt,
    rd,
    reg_in_hi,
    reg_in_lo,
    rs_out,
    rt_out
);
  input [31:0] reg_in_hi, reg_in_lo;
  input [4:0] rs, rt, rd;
  input clk, reg_write, hi_lo_enable;
  output [31:0] rs_out;
  output reg [31:0] rt_out;

  integer reg_index;
  reg [31:0] registers[16];
  reg [31:0] hi, lo;

  initial begin
    for (reg_index = 0; reg_index < 16; reg_index = reg_index + 1) begin
      registers[reg_index] = 32'b0;
    end
    hi = 32'b0;
    lo = 32'b0;
  end

  wire [3:0] rs_clipped, rt_clipped, rd_clipped;
  assign rs_clipped = rs[3:0];
  assign rt_clipped = rt[3:0];
  assign rd_clipped = rd[3:0];

  assign rs_out = (rs_clipped != 4'b0 && rs[4] == 0) ? registers[rs_clipped] : 32'b0;
  always @(*) begin
    if (rt[4] == 0) begin
      if (rt_clipped != 4'b0) begin
        rt_out = registers[rt_clipped];
      end else begin
        rt_out = 32'b0;
      end
    end else begin
      if (rt_clipped == 4'b0000) begin
        rt_out = hi;
      end else if (rt_clipped == 4'b0001) begin
        rt_out = lo;
      end else begin
        rt_out = 32'b0;
      end
    end
  end

  always @(posedge clk) begin
    if (reg_write) begin
      if (hi_lo_enable) begin
        hi <= reg_in_hi;
        lo <= reg_in_lo;
      end else if (rd[4] == 0 && rd_clipped != 4'b0) begin
        registers[rd_clipped] <= reg_in_lo;
      end
    end
  end
endmodule
