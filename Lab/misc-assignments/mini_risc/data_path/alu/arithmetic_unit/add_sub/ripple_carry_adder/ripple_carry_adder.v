module ripple_carry_adder(x, y, cin, s, ovfl);
  input [31:0] x, y;
  input cin;
  output [31:0] s;
  output ovfl;

  wire [32:0] c;

  assign c[0] = cin;
  assign ovfl = c[32] ^ c[31];

  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : full_adders
      full_adder fa (
        .A(x[i]),
        .B(y[i]),
        .Cin(c[i]),
        .S(s[i]),
        .Cout(c[i+1])
      );
    end
  endgenerate

endmodule
