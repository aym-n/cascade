`timescale 1ns/1ps

module tb_pe;
    reg clk, rst;
    reg signed [7:0] a_in, b_in;
    wire signed [7:0] a_out, b_out;
    wire signed [15:0] c_result;

    pe uut (.*); // SystemVerilog concise instantiation

    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_pe.vcd"); $dumpvars(0, tb_pe);
        
        // Test 1: Reset
        rst = 1; a_in = 0; b_in = 0;
        #15 rst = 0; 
        if(c_result !== 0) $display("FAIL: Reset");
        else $display("PASS: Reset");

        // Test 2: Simple MAC (2 * 3 = 6)
        @(posedge clk);
        a_in = 2; b_in = 3;
        @(posedge clk);
        a_in = 0; b_in = 0; // Stop inputs
        @(posedge clk); // Wait for pipeline
        if(c_result === 6) $display("PASS: 2*3=6");
        else $display("FAIL: Expected 6, Got %d", c_result);

        // Test 3: Accumulation (Previous 6 + (4*5) = 26)
        a_in = 4; b_in = 5;
        @(posedge clk);
        a_in = 0; b_in = 0;
        @(posedge clk);
        if(c_result === 26) $display("PASS: Accumulation 6+(4*5)=26");
        else $display("FAIL: Expected 26, Got %d", c_result);

        $finish;
    end
endmodule