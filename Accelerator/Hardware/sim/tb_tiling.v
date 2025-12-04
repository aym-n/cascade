`timescale 1ns/1ps

module tb_tiling;

    // Signals
    reg clk;
    reg rst_n;
    reg start;
    wire done;
    wire signed [15:0] result_check;

    // Instantiate the Tiler (UUT)
    systolic_tiler_6x6 uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        // Flat inputs are unused in this sim; we inject memory directly
        .A_flat_0(0), .A_flat_1(0), .A_flat_2(0), .A_flat_3(0), .A_flat_4(0), .A_flat_5(0), 
        .done(done),
        .result_check(result_check)
    );

    // Clock Generation
    initial begin
        clk = 0; forever #5 clk = ~clk;
    end

    // Simulation Variables
    integer i, j, k;
    reg signed [15:0] C_GOLD [0:5][0:5]; // Expected Result (Software)
    integer errors;

    initial begin
        $dumpfile("tb_tiling.vcd");
        $dumpvars(0, tb_tiling);
        
        $display("\n==================================================");
        $display("   Matrix Tiling Testbench (6x6 on 3x3 HW)");
        $display("==================================================");

        // Initialize signals
        rst_n = 0; start = 0;
        #20 rst_n = 1;

        // --- TEST CASE 1: Identity Matrix ---
        $display("\n\033[1;34m[TEST 1] A = Random, B = Identity\033[0m");
        // 1. Load Memory
        for(i=0; i<6; i=i+1) begin
            for(j=0; j<6; j=j+1) begin
                uut.A_MEM[i][j] = $random % 10;  // Random small numbers
                uut.B_MEM[i][j] = (i==j) ? 1 : 0; // Identity
                uut.C_MEM[i][j] = 0;             // Clear Result
            end
        end
        // 2. Run
        run_test_case();


        // --- TEST CASE 2: Constant Values (Check Accumulation) ---
        $display("\n\033[1;34m[TEST 2] A = All 2s, B = All 3s\033[0m");
        // Result should be: Row * Col * (2*3) = 6 * 6 = 36 for every element
        for(i=0; i<6; i=i+1) begin
            for(j=0; j<6; j=j+1) begin
                uut.A_MEM[i][j] = 2;
                uut.B_MEM[i][j] = 3;
                uut.C_MEM[i][j] = 0;
            end
        end
        run_test_case();


        // --- TEST CASE 3: Full Random ---
        $display("\n\033[1;34m[TEST 3] A = Random, B = Random\033[0m");
        for(i=0; i<6; i=i+1) begin
            for(j=0; j<6; j=j+1) begin
                uut.A_MEM[i][j] = ($random % 8) - 4; // Signed range [-4, 3]
                uut.B_MEM[i][j] = ($random % 8) - 4;
                uut.C_MEM[i][j] = 0;
            end
        end
        run_test_case();

        $finish;
    end

    // --- TASK: Run Simulation, Compute Golden, Verify, Print ---
    task run_test_case;
        begin
            // A. Calculate Golden Model (Software Reference)
            for(i=0; i<6; i=i+1) begin
                for(j=0; j<6; j=j+1) begin
                    C_GOLD[i][j] = 0;
                    for(k=0; k<6; k=k+1) begin
                        C_GOLD[i][j] = C_GOLD[i][j] + (uut.A_MEM[i][k] * uut.B_MEM[k][j]);
                    end
                end
            end

            // B. Start Hardware Simulation
            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            // C. Wait for Done
            wait(done);
            #20; // Small settling time

            // D. Print Matrices
            $display("\n--- Matrix A (Input) ---   --- Matrix B (Input) ---");
            for(i=0; i<6; i=i+1) begin
                // Print Row of A
                $write("[ ");
                for(j=0; j<6; j=j+1) $write("%3d ", uut.A_MEM[i][j]);
                $write("]   ");
                
                // Print Row of B
                $write("[ ");
                for(j=0; j<6; j=j+1) $write("%3d ", uut.B_MEM[i][j]);
                $write("]\n");
            end

            $display("\n--- Matrix C (Hardware Result) vs (Expected) ---");
            errors = 0;
            for(i=0; i<6; i=i+1) begin
                $write("Row %0d: [ ", i);
                for(j=0; j<6; j=j+1) begin
                    // Print Value
                    $write("%4d ", uut.C_MEM[i][j]);
                    
                    // Check Logic
                    if(uut.C_MEM[i][j] !== C_GOLD[i][j]) begin
                        errors = errors + 1;
                    end
                end
                $write("]  Expected: [ ");
                // Print Golden Row for comparison
                for(j=0; j<6; j=j+1) $write("%4d ", C_GOLD[i][j]);
                $write("]\n");
            end

            // E. Final Status
            if(errors == 0) 
                $display("\n\033[1;32m>> STATUS: PASSED (0 Errors)\033[0m");
            else 
                $display("\n\033[1;31m>> STATUS: FAILED (%0d Errors)\033[0m", errors);
            
            $display("--------------------------------------------------");
        end
    endtask

endmodule