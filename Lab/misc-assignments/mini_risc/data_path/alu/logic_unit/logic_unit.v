module logic_unit (
    x,
    y,
    log_func,
    log_out
);
  input [31:0] x, y;
  input [2:0] log_func;
  output [31:0] log_out;

  wire [31:0] and_out, or_out, not_out, nor_out, xor_out;

  and_gate andg (
      .x  (x),
      .y  (y),
      .out(and_out)
  );

  or_gate org (
      .x  (x),
      .y  (y),
      .out(or_out)
  );

  not_gate notg (
      .x  (x),
      .out(not_out)
  );

  nor_gate norg (
      .x  (x),
      .y  (y),
      .out(nor_out)
  );

  xor_gate xorg (
      .x  (x),
      .y  (y),
      .out(xor_out)
  );

  mux_8to1 #(
      .WIDTH(32)
  ) M (
      .I0 (and_out),
      .I1 (or_out),
      .I2 (not_out),
      .I3 (nor_out),
      .I4 (xor_out),
      .I5 (32'b0),
      .I6 (32'b0),
      .I7 (32'b0),
      .sel(log_func),
      .O  (log_out)
  );

endmodule
