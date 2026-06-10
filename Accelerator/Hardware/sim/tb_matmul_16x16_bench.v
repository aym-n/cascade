`timescale 1ns/1ps

// Cycle-count benchmark for 16x16 matmul (used by benchmark/compare.py).
module tb_matmul_16x16_bench;
    localparam N = 16;

    reg clk, rst_n, start;
    wire done;
    wire signed [31:0] result_sum;

    integer cycle_start, cycle_end, cycles_elapsed;
    integer i, j, k, errors;

    systolic_matmul_16x16 uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .result_sum(result_sum)
    );

    reg signed [15:0] C_GOLD [0:N-1][0:N-1];

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0;
        start = 0;
        #20 rst_n = 1;
        #10;

        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                uut.A_MEM[i][j] = ($random % 8) - 4;
                uut.B_MEM[i][j] = ($random % 8) - 4;
            end
        end

        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                C_GOLD[i][j] = 0;
                for (k = 0; k < N; k = k + 1) begin
                    C_GOLD[i][j] = C_GOLD[i][j] + (uut.A_MEM[i][k] * uut.B_MEM[k][j]);
                end
            end
        end

        @(posedge clk);
        cycle_start = $time;
        start = 1;
        @(posedge clk);
        start = 0;

        wait(done);
        @(posedge clk);
        cycle_end = $time;

        // 10 ns clock period
        cycles_elapsed = (cycle_end - cycle_start) / 10;

        errors = 0;
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (uut.C_MEM[i][j] !== C_GOLD[i][j])
                    errors = errors + 1;
            end
        end

        $display("BENCHMARK_SIZE=16");
        $display("BENCHMARK_MACS=%0d", N * N * N);
        $display("BENCHMARK_CYCLES=%0d", cycles_elapsed);
        $display("BENCHMARK_PASS=%0d", errors == 0 ? 1 : 0);
        $finish;
    end
endmodule
