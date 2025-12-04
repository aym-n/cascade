`timescale 1ns/1ps

module tb_systolic_array;

    reg clk, rst;
    
    // Inputs
    reg signed [7:0] a0, a1, a2;
    reg signed [7:0] b0, b1, b2;
    
    // Outputs (Scalars - Easier to see in VCD)
    wire signed [15:0] c00, c01, c02;
    wire signed [15:0] c10, c11, c12;
    wire signed [15:0] c20, c21, c22;
    
    // Array for verification logic (Packed from scalars below)
    reg signed [15:0] c_check [0:2][0:2];

    systolic_array_3x3 uut (
        .clk(clk), .rst(rst),
        .a0(a0), .a1(a1), .a2(a2),
        .b0(b0), .b1(b1), .b2(b2),
        // Connect explicit scalars
        .c00(c00), .c01(c01), .c02(c02),
        .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );

    // Pack scalars into array for easier verification loops
    always @(*) begin
        c_check[0][0] = c00; c_check[0][1] = c01; c_check[0][2] = c02;
        c_check[1][0] = c10; c_check[1][1] = c11; c_check[1][2] = c12;
        c_check[2][0] = c20; c_check[2][1] = c21; c_check[2][2] = c22;
    end

    // Test Data
    reg signed [7:0] A_MAT [0:2][0:2];
    reg signed [7:0] B_MAT [0:2][0:2];
    reg signed [15:0] C_GOLD [0:2][0:2]; 

    integer i, j, t;

    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    // Standard VCD Dump
    initial begin
        $dumpfile("tb_systolic_array.vcd");
        // Dump everything in this module (now including c00, c01... scalars)
        $dumpvars(0, tb_systolic_array);
    end

    task compute_expected;
        integer x, y, z;
        begin
            for(x=0; x<3; x=x+1) begin
                for(y=0; y<3; y=y+1) begin
                    C_GOLD[x][y] = 0;
                    for(z=0; z<3; z=z+1) begin
                        C_GOLD[x][y] = C_GOLD[x][y] + (A_MAT[x][z] * B_MAT[z][y]);
                    end
                end
            end
        end
    endtask

    initial begin
        
        // --- CASE 1: Identity Matrix ---
        $display("\nTest Case 1: Matrix A * Identity");
        
        A_MAT[0][0]=1; A_MAT[0][1]=2; A_MAT[0][2]=3;
        A_MAT[1][0]=4; A_MAT[1][1]=5; A_MAT[1][2]=6;
        A_MAT[2][0]=7; A_MAT[2][1]=8; A_MAT[2][2]=9;

        B_MAT[0][0]=1; B_MAT[0][1]=0; B_MAT[0][2]=0;
        B_MAT[1][0]=0; B_MAT[1][1]=1; B_MAT[1][2]=0;
        B_MAT[2][0]=0; B_MAT[2][1]=0; B_MAT[2][2]=1;
        
        compute_expected();
        run_systolic_pulse();
        check_results();

        // --- CASE 2: Random Values ---
        $display("\nTest Case 2: Random Values");
        rst = 1; #10 rst = 0; 
        
        for(i=0; i<3; i=i+1)
            for(j=0; j<3; j=j+1) begin
                A_MAT[i][j] = $random % 5; // Keeping numbers small for easy reading
                B_MAT[i][j] = $random % 5;
            end

        compute_expected();
        run_systolic_pulse();
        check_results();

        $finish;
    end

    task run_systolic_pulse;
        begin
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
        end
    endtask

    task check_results;
        integer err_cnt;
        begin
            err_cnt = 0;
            $display("       Expected        |        Actual");
            $display("-----------------------+-----------------------");
            for(i=0; i<3; i=i+1) begin
                $display("[%3d %3d %3d]  |  [%3d %3d %3d]", 
                    C_GOLD[i][0], C_GOLD[i][1], C_GOLD[i][2],
                    c_check[i][0], c_check[i][1], c_check[i][2]);
                
                for(j=0; j<3; j=j+1) begin
                    if(c_check[i][j] !== C_GOLD[i][j]) err_cnt++;
                end
            end
            
            if(err_cnt == 0) $display("STATUS: PASSED ");
            else $display("STATUS: FAILED (%0d errors)", err_cnt);
        end
    endtask

endmodule