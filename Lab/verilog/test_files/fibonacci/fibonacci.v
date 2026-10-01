module fibonacci (
    clk,
    reset,
    start,
    K,
    O
);
  input [7:0] K;
  output [7:0] O;
  input clk, reset, start;

  wire gt, sel0, sel1, selK, ld0, ld1, ldK, ldA;
  wire [7:0] A;
  wire [7:0] F0, F1;
  assign F0 = 8'b0;
  assign F1 = 8'b00000001;

  data_path dp (
      clk,
      K,
      F0,
      F1,
      sel0,
      sel1,
      selK,
      ld0,
      ld1,
      ldK,
      ldA,
      gt,
      A
  );

  control_path cp (
      clk,
      reset,
      start,
      gt,
      sel0,
      sel1,
      selK,
      ld0,
      ld1,
      ldK,
      ldA
  );

  assign O = A;

endmodule
