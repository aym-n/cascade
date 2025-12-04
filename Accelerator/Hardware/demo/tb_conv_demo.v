`timescale 1ns/1ps

module tb_conv_demo;
    reg clk, rst_n, start;
    wire done;
    wire signed [15:0] debug_out;
    conv_im2col uut (.clk(clk), .rst_n(rst_n), .start(start), .done(done), .debug_out(debug_out));
    initial begin clk=0; forever #5 clk=~clk; end
    integer i, j;

    initial begin
        // ==========================================
        // [DEMO] EDIT IMAGE & FILTERS HERE
        // ==========================================
        // Load Image (4x4)
        uut.IMG_MEM[0]=10; uut.IMG_MEM[1]=10; uut.IMG_MEM[2]=10; uut.IMG_MEM[3]=10;
        uut.IMG_MEM[4]=20; uut.IMG_MEM[5]=20; uut.IMG_MEM[6]=20; uut.IMG_MEM[7]=20;
        uut.IMG_MEM[8]=30; uut.IMG_MEM[9]=30; uut.IMG_MEM[10]=30; uut.IMG_MEM[11]=30;
        uut.IMG_MEM[12]=40; uut.IMG_MEM[13]=40; uut.IMG_MEM[14]=40; uut.IMG_MEM[15]=40;

        // Load Filter 0 (2x2) - Example: Edge Detect
        uut.W_MEM[0][0]=1; uut.W_MEM[0][1]=-1; uut.W_MEM[0][2]=1; uut.W_MEM[0][3]=-1;
        // ==========================================

        $display("\n--- Convolution Engine Demo ---");
        rst_n=0; start=0; #20 rst_n=1;
        #10 start=1; #10 start=0;
        wait(done); #20;

        $display("Feature Map Output (Filter 0):");
        for(i=0; i<3; i=i+1) begin
             $write("Row %0d: ", i);
             for(j=0; j<3; j=j+1) $write("[%4d] ", uut.OUT_MEM[i*3+j][0]);
             $write("\n");
        end
        $finish;
    end
endmodule