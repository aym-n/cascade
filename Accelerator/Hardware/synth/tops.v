// Synthesis tops for AWS F1 (xcvu9p) benchmarking.
// Each top exposes a minimal port list so Vivado does not optimize away the DUT.

module cascade_synth_top_array (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [ 7:0] a0,
    input  wire signed [ 7:0] a1,
    input  wire signed [ 7:0] a2,
    input  wire signed [ 7:0] b0,
    input  wire signed [ 7:0] b1,
    input  wire signed [ 7:0] b2,
    output wire signed [15:0] c00,
    output wire signed [15:0] c01,
    output wire signed [15:0] c02,
    output wire signed [15:0] c10,
    output wire signed [15:0] c11,
    output wire signed [15:0] c12,
    output wire signed [15:0] c20,
    output wire signed [15:0] c21,
    output wire signed [15:0] c22
);
    systolic_array_3x3 u_array (
        .clk(clk),
        .rst(rst),
        .a0(a0), .a1(a1), .a2(a2),
        .b0(b0), .b1(b1), .b2(b2),
        .c00(c00), .c01(c01), .c02(c02),
        .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );
endmodule

module cascade_synth_top_tiler (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    output wire               done,
    output wire signed [15:0] result_check
);
    systolic_tiler_6x6 u_tiler (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .A_flat_0(8'sd0),
        .A_flat_1(8'sd0),
        .A_flat_2(8'sd0),
        .A_flat_3(8'sd0),
        .A_flat_4(8'sd0),
        .A_flat_5(8'sd0),
        .done(done),
        .result_check(result_check)
    );
endmodule

module cascade_synth_top_conv (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    output wire               done,
    output wire signed [15:0] debug_out
);
    conv_im2col u_conv (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .debug_out(debug_out)
    );
endmodule
