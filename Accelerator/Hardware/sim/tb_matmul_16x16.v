`timescale 1ns/1ps

module tb_matmul_16x16;
    localparam N = 16;

    reg clk, rst_n, start;
    wire done;
    wire signed [31:0] result_sum;

    systolic_matmul_16x16 uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .result_sum(result_sum)
    );

    reg signed [15:0] C_GOLD [0:N-1][0:N-1];
    integer i, j, k;
    integer errors;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_matmul_16x16.vcd");
        $dumpvars(0, tb_matmul_16x16);

        rst_n = 0;
        start = 0;
        #20 rst_n = 1;

        $display("\n==================================================");
        $display("   16x16 Matrix Multiply (no tiling)");
        $display("==================================================");

        run_case("Identity", 0);
        run_case("All 2 x All 3", 1);
        run_case("Random signed", 2);

        $finish;
    end

    task run_case;
        input [255:0] name;
        input integer mode;
        begin
            errors = 0;
            load_matrices(mode);
            compute_golden();

            @(posedge clk);
            start = 1;
            @(posedge clk);
            start = 0;

            wait(done);
            #30;

            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    if (uut.C_MEM[i][j] !== C_GOLD[i][j]) begin
                        errors = errors + 1;
                        if (errors <= 8) begin
                            $display("MISMATCH [%0d][%0d]: got %0d expected %0d",
                                i, j, uut.C_MEM[i][j], C_GOLD[i][j]);
                        end
                    end
                end
            end

            if (errors == 0)
                $display("[PASS] %0s  (256/256 correct, sum=%0d)", name, result_sum);
            else
                $display("[FAIL] %0s  (%0d errors)", name, errors);

            @(posedge clk);
            wait(uut.state == 0);
        end
    endtask

    task load_matrices;
        input integer mode;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    case (mode)
                        0: begin
                            uut.A_MEM[i][j] = ($random % 10);
                            uut.B_MEM[i][j] = (i == j) ? 1 : 0;
                        end
                        1: begin
                            uut.A_MEM[i][j] = 2;
                            uut.B_MEM[i][j] = 3;
                        end
                        default: begin
                            uut.A_MEM[i][j] = ($random % 8) - 4;
                            uut.B_MEM[i][j] = ($random % 8) - 4;
                        end
                    endcase
                    uut.C_MEM[i][j] = 0;
                end
            end
        end
    endtask

    task compute_golden;
        begin
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    C_GOLD[i][j] = 0;
                    for (k = 0; k < N; k = k + 1) begin
                        C_GOLD[i][j] = C_GOLD[i][j] + (uut.A_MEM[i][k] * uut.B_MEM[k][j]);
                    end
                end
            end
        end
    endtask
endmodule
