module not_gate (
    x,
    out
);
  input [31:0] x;
  output [31:0] out;

  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : g_not_gates
      not (out[i], x[i]);
    end
  endgenerate
endmodule
