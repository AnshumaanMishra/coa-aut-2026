module sign_extender #(
    parameter integer WIDTH = 32
) (
    imm_in,
    se_imm
);
  input [15:0] imm_in;
  output [WIDTH-1:0] se_imm;

  assign se_imm = {{(WIDTH - 16) {imm_in[15]}}, imm_in[15:0]};

endmodule
