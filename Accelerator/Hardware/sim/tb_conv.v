`timescale 1ns/1ps

module tb_conv;

    reg clk, rst_n, start;
    wire done;
    wire signed [15:0] debug_out;

    conv_im2col uut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .done(done), .debug_out(debug_out)
    );

    // Clock Generation
    initial begin
        clk = 0; 
        forever #5 clk = ~clk;
    end

    integer i, j;
    integer errors;
    reg signed [15:0] expected_val;
    reg signed [15:0] actual_val;
    
    // Helper function to calculate Image Value at (y,x)
    // Matches the pattern in RTL: val = y*4 + x
    function [7:0] get_img_val;
        input integer y, x;
        begin
            get_img_val = (y * 4) + x;
        end
    endfunction

    initial begin
        $dumpfile("tb_conv.vcd"); $dumpvars(0, tb_conv);
        
        rst_n = 0; start = 0;
        #20 rst_n = 1;
        
        $display("\n=========================================");
        $display("   Convolution Engine Test (im2col)");
        $display("=========================================");
        $display("Image: 4x4 (Values 0..15)");
        $display("Kernels: 3 Filters (2x2 size)");
        $display("  - Filter 0: Sum (All 1s)");
        $display("  - Filter 1: Top-Left * 2");
        $display("  - Filter 2: Bottom-Right * 3");
        
        // Start Hardware
        #10 start = 1;
        #10 start = 0;
        
        // Wait for completion
        wait(done);
        #20;
        
        errors = 0;
        $display("\n--- Verifying All 27 Output Values ---");
        
        // Loop through 3x3 Output Feature Map
        for(i=0; i<3; i=i+1) begin
            for(j=0; j<3; j=j+1) begin
                
                // --- CHECK FILTER 0 (Sum) ---
                // Logic: Sum of pixels in 2x2 window
                expected_val = get_img_val(i,j) + get_img_val(i,j+1) + 
                               get_img_val(i+1,j) + get_img_val(i+1,j+1);
                actual_val = uut.OUT_MEM[i*3 + j][0];
                
                if(actual_val !== expected_val) begin
                    $display("\033[1;31m[FAIL] Px(%0d,%0d) Filt 0: Exp %d, Got %d\033[0m", i, j, expected_val, actual_val);
                    errors = errors + 1;
                end

                // --- CHECK FILTER 1 (Top-Left * 2) ---
                // Logic: Only the first weight is 2, others 0
                expected_val = get_img_val(i,j) * 2;
                actual_val = uut.OUT_MEM[i*3 + j][1];
                
                if(actual_val !== expected_val) begin
                    $display("\033[1;31m[FAIL] Px(%0d,%0d) Filt 1: Exp %d, Got %d\033[0m", i, j, expected_val, actual_val);
                    errors = errors + 1;
                end

                // --- CHECK FILTER 2 (Bottom-Right * 3) ---
                // Logic: Only the last weight is 3, others 0
                expected_val = get_img_val(i+1,j+1) * 3;
                actual_val = uut.OUT_MEM[i*3 + j][2];
                
                if(actual_val !== expected_val) begin
                    $display("\033[1;31m[FAIL] Px(%0d,%0d) Filt 2: Exp %d, Got %d\033[0m", i, j, expected_val, actual_val);
                    errors = errors + 1;
                end
            end
        end
        
        // Print Visual Map for Filter 0 (Sum)
        $display("\nOutput Map (Filter 0 - Sum):");
        for(i=0; i<3; i=i+1) begin
            $write("Row %0d: ", i);
            for(j=0; j<3; j=j+1) $write("[%4d] ", uut.OUT_MEM[i*3+j][0]);
            $write("\n");
        end

        if (errors == 0) 
            $display("\n\033[1;32m>> ALL CHECKS PASSED (27/27 Values correct)\033[0m");
        else
            $display("\n\033[1;31m>> FAILED: Found %0d errors.\033[0m", errors);

        $finish;
    end
endmodule