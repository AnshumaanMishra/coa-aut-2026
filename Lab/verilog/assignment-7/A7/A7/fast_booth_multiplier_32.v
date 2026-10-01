module fast_booth_multiplier_32(
    input wire clk,
    input wire reset,
    input wire start,
    input wire signed [31:0] multiplier,
    input wire signed [31:0] multiplicand,
    output wire signed [63:0] product,
    output wire busy,
    output wire done
);
    wire ldInput, ldProduct, slow_clk;

    clock_divider_counter cdc(
        .clk(clk),
        .slow_clk(slow_clk)
    );

    control_path cp(
        .clk(slow_clk),
        .reset(reset),
        .start(start),
        .ldInput(ldInput),
        .ldProduct(ldProduct),
        .busy(busy),
        .done(done)
    );

    data_path dp(
        .clk(slow_clk),
        .reset(reset),
        .ldInput(ldInput),
        .ldProduct(ldProduct),
        .multiplier(multiplier),
        .multiplicand(multiplicand),
        .product(product)
    );
endmodule
