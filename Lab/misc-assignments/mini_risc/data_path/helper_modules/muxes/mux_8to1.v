module mux_8to1 #(
    parameter integer WIDTH = 32
) (
    I0,
    I1,
    I2,
    I3,
    I4,
    I5,
    I6,
    I7,
    sel,
    O
);
  input [WIDTH-1:0] I0, I1, I2, I3, I4, I5, I6, I7;
  input [2:0] sel;
  output [WIDTH-1:0] O;

  wire [WIDTH-1:0] O0, O1;

  mux_4to1 #(
      .WIDTH(WIDTH)
  ) M1 (
      .I0 (I0),
      .I1 (I1),
      .I2 (I2),
      .I3 (I3),
      .sel(sel[1:0]),
      .O  (O0)
  );

  mux_4to1 #(
      .WIDTH(WIDTH)
  ) M2 (
      .I0 (I4),
      .I1 (I5),
      .I2 (I6),
      .I3 (I7),
      .sel(sel[1:0]),
      .O  (O1)
  );

  mux_2to1 #(
      .WIDTH(WIDTH)
  ) M3 (
      .I0 (O0),
      .I1 (O1),
      .sel(sel[2]),
      .O  (O)
  );

endmodule


