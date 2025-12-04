`timescale 1ns/1ps

module tb_array_demo;
    reg clk, rst;
    reg signed [7:0] a0, a1, a2, b0, b1, b2;
    wire signed [15:0] c00, c01, c02, c10, c11, c12, c20, c21, c22;
    reg signed [7:0] A_MAT [0:2][0:2];
    reg signed [7:0] B_MAT [0:2][0:2];
    integer t, i, j;

    systolic_array_3x3 uut (
        .clk(clk), .rst(rst),
        .a0(a0), .a1(a1), .a2(a2), .b0(b0), .b1(b1), .b2(b2),
        .c00(c00), .c01(c01), .c02(c02), .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );

    initial begin clk=0; forever #5 clk=~clk; end

    initial begin
        // ==========================================
        // [DEMO] EDIT MATRIX A & B HERE
        // ==========================================
        // Matrix A
        A_MAT[0][0]=2; A_MAT[0][1]=0; A_MAT[0][2]=0;
        A_MAT[1][0]=0; A_MAT[1][1]=1; A_MAT[1][2]=0;
        A_MAT[2][0]=0; A_MAT[2][1]=0; A_MAT[2][2]=1;
        // Matrix B
        B_MAT[0][0]=1; B_MAT[0][1]=0; B_MAT[0][2]=0;
        B_MAT[1][0]=0; B_MAT[1][1]=2; B_MAT[1][2]=0;
        B_MAT[2][0]=0; B_MAT[2][1]=0; B_MAT[2][2]=3;
        // ==========================================

        $display("\n--- 3x3 Systolic Array Demo ---");
        rst = 1; 
        {a0,a1,a2,b0,b1,b2} = 0;
        @(posedge clk);
        rst = 0;
            
        // Feed data for 10 cycles
         for(t=0; t<10; t=t+1) begin
                // Skewing Logic
            a0 <= (t>=0 && t<3) ? A_MAT[0][t-0] : 0;
            a1 <= (t>=1 && t<4) ? A_MAT[1][t-1] : 0;
                a2 <= (t>=2 && t<5) ? A_MAT[2][t-2] : 0;

            b0 <= (t>=0 && t<3) ? B_MAT[t-0][0] : 0;
            b1 <= (t>=1 && t<4) ? B_MAT[t-1][1] : 0;
            b2 <= (t>=2 && t<5) ? B_MAT[t-2][2] : 0;
            @(posedge clk);
        end
            
        repeat(10) @(posedge clk);

        $display("Output Matrix C:");
        $display("[%4d %4d %4d]", c00, c01, c02);
        $display("[%4d %4d %4d]", c10, c11, c12);
        $display("[%4d %4d %4d]", c20, c21, c22);
        $finish;
    end
endmodule