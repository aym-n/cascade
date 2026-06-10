module pe (
    input clk,
    input rst,
    input signed [7:0] a_in,
    input signed [7:0] b_in,
    output reg signed [7:0] a_out,
    output reg signed [7:0] b_out,
    output reg signed [15:0] c_result
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            a_out <= 0;
            b_out <= 0;
            c_result <= 0;
        end else begin
            a_out <= a_in;
            b_out <= b_in;
            c_result <= c_result + (a_in * b_in);
        end
    end
endmodule