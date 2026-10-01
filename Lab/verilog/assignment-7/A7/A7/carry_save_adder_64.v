module carry_save_adder_64(
    input wire [63:0] x,
    input wire [63:0] y,
    input wire [63:0] z,
    output wire [63:0] s,
    output wire [63:0] c
);
    assign s = x ^ y ^ z;
    assign c = ((x & y) | (y & z) | (z & x)) << 1;
endmodule
