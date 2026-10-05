module multiplier (
    x,
    y,
    ovfl,
    mul_hi_out,
    mul_lo_out
);

  input [31:0] x, y;
  output ovfl;
  output [31:0] mul_hi_out, mul_lo_out;

  wire [63:0] raw_pp[0:15];
  wire [63:0] PP[0:15];

  wire [63:0] r1, r2, r3, r4, r5;
  wire [63:0] c1, c2, c3, c4, c5;
  wire [63:0] r6, r7, r8;
  wire [63:0] c6, c7, c8;
  wire [63:0] r9, r10;
  wire [63:0] c9, c10;
  wire [63:0] r11, r12;
  wire [63:0] c11, c12;
  wire [63:0] r13, c13;
  wire [63:0] r14, c14;

  wire [63:0] final_sum;
  wire final_cout;

  genvar i;

  generate
    for (i = 0; i < 16; i = i + 1) begin : g_booth
      if (i == 0) begin : g_first
        booth_recoder #(
            .WIDTH(32)
        ) brec (
            .Q1 (y[1]),
            .Q0 (y[0]),
            .Qm1(1'b0),
            .M  (x),
            .O  (raw_pp[i])
        );
      end else begin : g_other
        booth_recoder #(
            .WIDTH(32)
        ) brec (
            .Q1 (y[2*i+1]),
            .Q0 (y[2*i]),
            .Qm1(y[2*i-1]),
            .M  (x),
            .O  (raw_pp[i])
        );
      end

      assign PP[i] = raw_pp[i] << (2 * i);
    end
  endgenerate

  carry_save_adder #(
      .WIDTH(64)
  ) csa1 (
      .A(PP[0]),
      .B(PP[1]),
      .C(PP[2]),
      .S(r1),
      .Cout(c1)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa2 (
      .A(PP[3]),
      .B(PP[4]),
      .C(PP[5]),
      .S(r2),
      .Cout(c2)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa3 (
      .A(PP[6]),
      .B(PP[7]),
      .C(PP[8]),
      .S(r3),
      .Cout(c3)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa4 (
      .A(PP[9]),
      .B(PP[10]),
      .C(PP[11]),
      .S(r4),
      .Cout(c4)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa5 (
      .A(PP[12]),
      .B(PP[13]),
      .C(PP[14]),
      .S(r5),
      .Cout(c5)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa6 (
      .A(r1),
      .B(c1 << 1),
      .C(r2),
      .S(r6),
      .Cout(c6)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa7 (
      .A(c2 << 1),
      .B(r3),
      .C(r4),
      .S(r7),
      .Cout(c7)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa8 (
      .A(c3 << 1),
      .B(c4 << 1),
      .C(r5),
      .S(r8),
      .Cout(c8)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa9 (
      .A(r6),
      .B(c6 << 1),
      .C(r7),
      .S(r9),
      .Cout(c9)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa10 (
      .A(c7 << 1),
      .B(r8),
      .C(c8 << 1),
      .S(r10),
      .Cout(c10)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa11 (
      .A(r9),
      .B(c9 << 1),
      .C(r10),
      .S(r11),
      .Cout(c11)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa12 (
      .A(c10 << 1),
      .B(c5 << 1),
      .C(PP[15]),
      .S(r12),
      .Cout(c12)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa13 (
      .A(r11),
      .B(c11 << 1),
      .C(r12),
      .S(r13),
      .Cout(c13)
  );

  carry_save_adder #(
      .WIDTH(64)
  ) csa14 (
      .A(r13),
      .B(c13 << 1),
      .C(c12 << 1),
      .S(r14),
      .Cout(c14)
  );

  ripple_carry_adder_2 #(
      .WIDTH(64)
  ) rca (
      .A(r14),
      .B_in(c14 << 1),
      .addsub(1'b0),
      .S(final_sum),
      .Cout(final_cout)
  );

  assign {mul_hi_out, mul_lo_out} = final_sum;
  assign ovfl = final_cout;

endmodule


