module clock_divider_counter(slow_clk, clk);
    output slow_clk;
    input clk;

    reg [25:0] clk_div;

    initial
        clk_div = 0;
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end

    assign slow_clk = clk;

endmodule
