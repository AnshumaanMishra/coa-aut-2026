module adder_64(
    input wire [63:0] a,
    input wire [63:0] b,
    output wire [63:0] sum
);
    assign sum = a + b;
endmodule
