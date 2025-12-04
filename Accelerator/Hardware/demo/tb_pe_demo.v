`timescale 1ns/1ps

module tb_pe_demo;
    reg clk, rst;
    reg signed [7:0] a_in, b_in;
    wire signed [7:0] a_out, b_out;
    wire signed [15:0] c_result;

    reg signed [7:0] input_a, input_b;
    reg signed [15:0] current_sum;

    pe uut (.*);

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        // ========================================== 
        // [DEMO] EDIT THESE VALUES 
        // ==========================================
        input_a = 5;
        input_b = 4;
        current_sum = 10;
        // ==========================================

        rst = 1; a_in = 0; b_in = 0;
        #15 rst = 0;

        // preload accumulator register inside PE
        uut.c_result = current_sum;

        $display("\n--- Processing Element Demo ---");
        $display("Operation: (%d * %d) + %d", input_a, input_b, current_sum);

        @(posedge clk); a_in = input_a; b_in = input_b;
        @(posedge clk); a_in = 0; b_in = 0;
        @(posedge clk);

        release uut.c_result;   // allow PE to take over again

        $display("\033[1;32mResult: %d\033[0m", c_result);
        $finish;
    end
endmodule
