module data_path (
    clk,
    _K,
    F_0,
    F_1,
    sel0,
    sel1,
    selK,
    ld0,
    ld1,
    ldK,
    ldA,
    gt,
    _A
);
  input [7:0] _K, F_0, F_1;
  input clk;
  input sel0, sel1, selK;
  input ld0, ld1, ldK, ldA;
  output gt;
  output [7:0] _A;

  wire [7:0] mux0_out, mux1_out, muxK_out;
  wire [7:0] f0_out, f1_out, K_out, A_out;
  wire [7:0] adder_out, dec_out;

  mux M0 (
      .I0 (F_0),
      .I1 (f1_out),
      .sel(sel0),
      .O  (mux0_out)
  );
  mux M1 (
      .I0 (F_1),
      .I1 (adder_out),
      .sel(sel1),
      .O  (mux1_out)
  );
  mux MK (
      .I0 (_K),
      .I1 (dec_out),
      .sel(selK),
      .O  (muxK_out)
  );

  register F0 (
      .clk (clk),
      .data(mux0_out),
      .read(~ld0),
      .out (f0_out)
  );
  register F1 (
      .clk (clk),
      .data(mux1_out),
      .read(~ld1),
      .out (f1_out)
  );
  register K (
      .clk (clk),
      .data(muxK_out),
      .read(~ldK),
      .out (K_out)
  );
  register A (
      .clk (clk),
      .data(f0_out),
      .read(~ldA),
      .out (A_out)
  );

  adder ADD (
      .I0(f0_out),
      .I1(f1_out),
      .O (adder_out)
  );

  comparator COMP (
      .I(K_out),
      .O(gt)
  );

  decrementer DEC (
      .K(K_out),
      .O(dec_out)
  );

  assign _A = A_out;
endmodule
