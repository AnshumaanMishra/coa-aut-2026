module bidirectional_led_shift(clk, reset, enable, direction, led);
  input clk, reset, enable, direction;
  output [4:0] led;

  wire slow_clk;

  clock_divider_counter cdc(
    .clk(clk),
    .reset(reset),
    .slow_ck(slow_clk)
 );

  reg [4:0] Q;

  always @(posedge slow_clk or posedge reset) begin
    if(reset) begin
      Q <= 5'b00001;
    end
    else if(enable) begin
      if(direction) begin
        Q[0] <= Q[4];
        Q[1] <= Q[0];
        Q[2] <= Q[1];
        Q[3] <= Q[2];
        Q[4] <= Q[3];
      end
      else begin
        Q[0] <= Q[1];
        Q[1] <= Q[2];
        Q[2] <= Q[3];
        Q[3] <= Q[4];
        Q[4] <= Q[0];
      end
    end
  end

  assign led = Q;

endmodule
