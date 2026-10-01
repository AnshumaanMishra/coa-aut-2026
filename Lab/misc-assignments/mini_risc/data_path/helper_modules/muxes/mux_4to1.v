module mux_4to1 #(
    parameter integer WIDTH = 32
) (
    I0,
    I1,
    I2,
    I3,
    sel,
    O
);
  input [WIDTH-1:0] I0, I1, I2, I3;
  input [1:0] sel;
  output [WIDTH-1:0] O;

  wire [WIDTH-1:0] O0, O1;

  mux_2to1 #(
      .WIDTH(WIDTH)
  ) M1 (
      .I0 (I0),
      .I1 (I1),
      .sel(sel[0]),
      .O  (O0)
  );

  mux_2to1 #(
      .WIDTH(WIDTH)
  ) M2 (
      .I0 (I2),
      .I1 (I3),
      .sel(sel[0]),
      .O  (O1)
  );

  mux_2to1 #(
      .WIDTH(WIDTH)
  ) M3 (
      .I0 (O0),
      .I1 (O1),
      .sel(sel[1]),
      .O  (O)
  );

endmodule

