module clock_divider_counter(clk, reset, slow_ck);

  input clk, reset;
  output slow_ck;

  reg [31:0] counter;

  initial begin
    counter = 32'd0;
  end

  always @(posedge clk or posedge reset) begin
    if (reset)
      counter <= 32'd0;
    else
      counter <= counter + 1;
  end

  assign slow_ck = counter[20];

endmodule

