`timescale 1ns / 1ps

module tb;
    reg clk;
    reg reset;
    reg start;
    reg signed [31:0] multiplicand;
    reg signed [31:0] multiplier;

    wire signed [63:0] product;
    wire busy;
    wire done;

    fast_booth_multiplier_32 uut (
        .clk(clk),
        .reset(reset),
        .start(start),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .product(product),
        .busy(busy),
        .done(done)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task run_test;
        input signed [31:0] test_M;
        input signed [31:0] test_Q;
        input signed [63:0] expected_P;
        begin
            @(negedge clk);
            multiplicand = test_M;
            multiplier = test_Q;
            start = 1;

            @(negedge clk);
            start = 0;
            wait(done == 1);
            if (product === expected_P) begin
                $display("[PASS] %d * %d = %d", test_M, test_Q, product);
            end else begin
                $display("[FAIL] %d * %d | Expected: %d, Got: %d", test_M, test_Q, expected_P, product);
            end
            repeat(3) @(negedge clk);
        end
    endtask

    initial begin
        reset = 1;
        start = 0;
        multiplicand = 0;
        multiplier = 0;
        #20;
        reset = 0;
        #10;

        $display("--- Starting Behavioral Simulation Tests ---");

        run_test(32'd100, 32'd25, 64'd2500);
        run_test(-32'd100, 32'd25, -64'd2500);
        run_test(-32'd100, -32'd25, 64'd2500);
        run_test(32'd0, 32'd123456, 64'd0);
        run_test(32'd1, -32'd123456, -64'd123456);
        run_test(32'd2147483647, 32'd1, 64'd2147483647);
        run_test(-32'd2147483648, 32'd1, -64'd2147483648);
        run_test(-32'd2147483648, -32'd1, 64'd2147483648);

        multiplicand = $random;
        multiplier = $random;
        run_test(multiplicand, multiplier, multiplicand * multiplier);

        $display("--- Simulation Complete ---");
        $finish;
    end

endmodule
