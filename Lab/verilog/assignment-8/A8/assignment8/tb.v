// Group Number: 5
// Members: Anshumaan Mishra (24CS10082), Saksham Kumar (24CS10029)


`timescale 1ns/1ps

module tb_mac_booth_board();

    reg clk;
    reg reset;
    reg signed [15:0] sw;
    wire signed [15:0] led;

    integer     errors;
    integer     i;
    reg  signed [15:0] expected_acc;
    reg  signed [15:0] expected_product;

    mac_booth_board dut (
        .clk(clk),
        .reset(reset),
        .sw(sw),
        .led(led)
    );

    initial clk = 1'b0;
    always #20 clk = ~clk;

    task wait_slow_edge;
        begin
            @(posedge dut.slow_clk);
        end
    endtask

    task apply_reset;
        begin
            reset = 1'b1;
            @(posedge clk); @(posedge clk); @(posedge clk);
            if (led !== 16'd0) begin
                errors = errors + 1;
                $display("[%0t] FAIL: LEDs did not clear on reset, led=%h", $time, led);
            end else begin
                $display("[%0t] PASS: reset clears accumulator/LEDs", $time);
            end
            reset = 1'b0;
        end
    endtask

    task run_case;
        input signed [7:0] a_val;
        input signed [7:0] b_val;
        input integer      n_updates;
        begin
            sw = {b_val, a_val};
            apply_reset;

            expected_product = dut.product16;
            expected_acc     = 16'sd0;

            $display("[%0t] Case A=%0d B=%0d  expected product=%0d",
                      $time, a_val, b_val, expected_product);

            for (i = 1; i <= n_updates; i = i + 1) begin
                wait_slow_edge;
                #1;
                expected_acc = expected_acc + expected_product;
                if (led !== expected_acc[15:0]) begin
                    errors = errors + 1;
                    $display("[%0t] FAIL update %0d: led=%h (%0d) expected=%h (%0d)",
                              $time, i, led, $signed(led), expected_acc[15:0], expected_acc);
                end else begin
                    $display("[%0t] PASS update %0d: acc=%0d (led=%h)",
                              $time, i, expected_acc, led);
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        sw     = 16'd0;
        reset  = 1'b1;

        $dumpfile("mac_booth_board_tb.vcd");
        $dumpvars(0, tb_mac_booth_board);

        @(posedge clk);
        @(posedge clk);

        run_case(8'sd3, 8'sd2, 5);
        run_case(8'sd5, -8'sd2, 5);
        run_case(-8'sd3, -8'sd4, 5);
        run_case(8'sd7, 8'sd1, 3);
        $display("[%0t] Asserting reset mid-run to re-check reset behavior", $time);
        apply_reset;
        run_case(8'sd127, 8'sd127, 6);

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("--------------------------------------------------");

        #50;
        $finish;
    end

endmodule
