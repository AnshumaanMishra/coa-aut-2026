// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)
// Assignment: Verilog Assignment 7
// Date of Submission: 07/09/2026

module data_path (
    input wire clk,
    input wire reset,
    input wire ldInput,
    input wire ldProduct,
    input wire signed [31:0] multiplier,
    input wire signed [31:0] multiplicand,
    output reg signed [63:0] product
);
    reg signed [31:0] M, Q;

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            M <= 32'd0;
            Q <= 32'd0;
        end
        else if (ldInput) begin
            M <= multiplicand;
            Q <= multiplier;
        end
    end

    wire signed [63:0] pp [0:15];
    wire [32:0] Qnew = {Q, 1'b0};

    genvar i;
    generate
        for(i = 0; i < 16; i = i + 1) begin: genPP
            wire zero, negative, double;
            booth_encoder_radix4 encoder(
                .bits(Qnew[2*i+2: 2*i]),
                .zero(zero),
                .negative(negative),
                .double(double)
            );
            partial_product_generator ppg(
                .multiplicand(M),
                .zero(zero),
                .negative(negative),
                .double(double),
                .shift_idx(i[4:0]),
                .pp(pp[i])
            );
        end
    endgenerate

    // CSA reduction
    wire [63:0] s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14;
    wire [63:0] c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14;

    // 16 -> 11
    carry_save_adder_64 csa1 (pp[0], pp[1], pp[2], s1, c1);
    carry_save_adder_64 csa2 (pp[3], pp[4], pp[5], s2, c2);
    carry_save_adder_64 csa3 (pp[6], pp[7], pp[8], s3, c3);
    carry_save_adder_64 csa4 (pp[9], pp[10], pp[11], s4, c4);
    carry_save_adder_64 csa5 (pp[12], pp[13], pp[14], s5, c5);

    // 11 -> 8
    carry_save_adder_64 csa6 (s1, c1, s2, s6, c6);
    carry_save_adder_64 csa7 (c2, s3, c3, s7, c7);
    carry_save_adder_64 csa8 (s4, c4, s5, s8, c8);

    // 8 -> 6
    carry_save_adder_64 csa9 (s6, c6, s7, s9, c9);
    carry_save_adder_64 csa10 (c7, s8, c8, s10, c10);

    // 6 -> 4
    carry_save_adder_64 csa11 (s9, c9, s10, s11, c11);
    carry_save_adder_64 csa12 (c10, c5, pp[15], s12, c12);

    // 4 -> 3
    carry_save_adder_64 csa13 (s11, c11, s12, s13, c13);

    // 3 -> 2
    carry_save_adder_64 csa14 (s13, c13, c12, s14, c14);

    // finally add these two
    wire [63:0] sum;
    adder_64 ad(.a(s14), .b(c14), .sum(sum));

    always @(posedge clk or posedge reset) begin
        if(reset) product <= 64'd0;
        else if(ldProduct) product <= sum;
    end
endmodule
