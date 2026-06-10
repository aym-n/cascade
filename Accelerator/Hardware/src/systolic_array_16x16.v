// 16x16 output-stationary systolic array (256 PEs, no tiling).
module systolic_array_16x16 (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [ 7:0] a_in [0:15],
    input  wire signed [ 7:0] b_in [0:15],
    output wire signed [15:0] c_out [0:15][0:15]
);
    localparam N = 16;

    wire signed [7:0]  a_wire [0:N-1][0:N];
    wire signed [7:0]  b_wire [0:N][0:N-1];
    wire signed [15:0] c_wire [0:N-1][0:N-1];

    genvar i, j;
    generate
        for (i = 0; i < N; i = i + 1) begin : A_IN
            assign a_wire[i][0] = a_in[i];
        end
        for (j = 0; j < N; j = j + 1) begin : B_IN
            assign b_wire[0][j] = b_in[j];
        end
        for (i = 0; i < N; i = i + 1) begin : ROWS
            for (j = 0; j < N; j = j + 1) begin : COLS
                pe pe_inst (
                    .clk(clk),
                    .rst(rst),
                    .a_in(a_wire[i][j]),
                    .b_in(b_wire[i][j]),
                    .a_out(a_wire[i][j+1]),
                    .b_out(b_wire[i+1][j]),
                    .c_result(c_wire[i][j])
                );
            end
        end
        for (i = 0; i < N; i = i + 1) begin : C_OUT
            for (j = 0; j < N; j = j + 1) begin : C_COLS
                assign c_out[i][j] = c_wire[i][j];
            end
        end
    endgenerate
endmodule
