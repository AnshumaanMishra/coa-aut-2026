module booth_recoder #(
    parameter integer WIDTH = 32
) (
    Q1,
    Q0,
    Qm1,
    M,
    O
);
  input Q1, Q0, Qm1;
  input [WIDTH-1:0] M;
  output reg [2*WIDTH-1:0] O;

  reg signed [2*WIDTH-1:0] MSE;

  always @(*) begin
    MSE = {{WIDTH{M[WIDTH-1]}}, M};

    case ({Q1, Q0, Qm1})
      3'b000,
      3'b111: O = {2*WIDTH{1'b0}};
      3'b001,
      3'b010: O = MSE;
      3'b011: O = MSE <<< 1;
      3'b100: O = -(MSE <<< 1);
      3'b101,
      3'b110: O = -MSE;
      default: O = {2*WIDTH{1'b0}};
    endcase
  end
endmodule
