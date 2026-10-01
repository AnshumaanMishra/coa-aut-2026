module mux_4to1_5bit(I0, I1, I2, I3, sel, Y);
  input [4:0] I0, I1, I2, I3;
  input [1:0] sel;
  output reg [4:0] Y;

  always @(*) begin
    case(sel)
      2'b00: begin
        Y = I0;
      end
      2'b01: begin
        Y = I1;
      end
      2'b10: begin
        Y = I2;
      end
      2'b11: begin
        Y = I3;
      end
      default: begin
        Y = 5'b0;
      end
    endcase
  end

endmodule
