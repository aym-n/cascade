`timescale 1ns/1ps

module tb_tiling_demo;
    reg clk, rst_n, start;
    wire done;
    wire signed [15:0] result_check;
    systolic_tiler_6x6 uut (.clk(clk), .rst_n(rst_n), .start(start), .done(done), .result_check(result_check),
                            .A_flat_0(8'd0), .A_flat_1(8'd0), .A_flat_2(8'd0), .A_flat_3(8'd0), .A_flat_4(8'd0), .A_flat_5(8'd0));

    initial begin clk=0; forever #5 clk=~clk; end
    integer i, j;

    initial begin

        rst_n = 0; start = 0;
        #20 rst_n = 1;
        // ==========================================
        // [DEMO] EDIT 6x6 MATRICES HERE
        // ==========================================
        // Example: Set A to all 2s, B to Identity
        for(i=0; i<6; i=i+1) begin
            for(j=0; j<6; j=j+1) begin
                uut.A_MEM[i][j] = 2;              // Matrix A
                uut.B_MEM[i][j] = (i > j) ? 1 : 0; // Matrix B
            end
        end
        // ==========================================

        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        #20; // Small settling time

        $display("\n--- 6x6 Tiling Engine Demo ---");

        $display("Result Matrix C (6x6):");
        for(i=0; i<6; i=i+1) begin
            $display("Row %0d: [ %4d %4d %4d %4d %4d %4d ]", i, 
                uut.C_MEM[i][0], uut.C_MEM[i][1], uut.C_MEM[i][2],
                uut.C_MEM[i][3], uut.C_MEM[i][4], uut.C_MEM[i][5]);
        end
        $finish;
    end
endmodule