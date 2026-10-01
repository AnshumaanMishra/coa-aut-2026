module and_gate (
    x,
    y,
    out
);
  input [31:0] x, y;
  output [31:0] out;

  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : g_and_gates
      and (out[i], x[i], y[i]);
    end
  endgenerate
endmodule
