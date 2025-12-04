module systolic_array_3x3 (
    input clk,
    input rst,
    input signed [7:0] a0, a1, a2,
    input signed [7:0] b0, b1, b2,
    output signed [15:0] c00, c01, c02,
    output signed [15:0] c10, c11, c12,
    output signed [15:0] c20, c21, c22
);

    wire signed [7:0] a_wire [0:2][0:3]; 
    wire signed [7:0] b_wire [0:3][0:2];
    wire signed [15:0] c_wire [0:2][0:2];

    assign a_wire[0][0] = a0; assign a_wire[1][0] = a1; assign a_wire[2][0] = a2;
    assign b_wire[0][0] = b0; assign b_wire[0][1] = b1; assign b_wire[0][2] = b2;

    genvar i, j;
    generate
        for (i = 0; i < 3; i = i + 1) begin : ROWS
            for (j = 0; j < 3; j = j + 1) begin : COLS
                pe pe_inst (
                    .clk(clk), .rst(rst),
                    .a_in(a_wire[i][j]), .b_in(b_wire[i][j]),
                    .a_out(a_wire[i][j+1]), .b_out(b_wire[i+1][j]),
                    .c_result(c_wire[i][j])
                );
            end
        end
    endgenerate

    assign c00 = c_wire[0][0]; assign c01 = c_wire[0][1]; assign c02 = c_wire[0][2];
    assign c10 = c_wire[1][0]; assign c11 = c_wire[1][1]; assign c12 = c_wire[1][2];
    assign c20 = c_wire[2][0]; assign c21 = c_wire[2][1]; assign c22 = c_wire[2][2];

endmodule