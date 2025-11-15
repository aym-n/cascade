module processing_element (
    input clk,
    input rst,
    input signed [7:0] a_in,  // Input A (8-bit signed)
    input signed [7:0] b_in,  // Input B (8-bit signed)
    input signed [15:0] c_in,  // Partial sum in
    
    output reg signed [7:0] a_out, // Pipelined A
    output reg signed [7:0] b_out, // Pipelined B
    output reg signed [15:0] c_out  // Partial sum out
);

    // Internal registers to pipeline the operation
    reg signed [7:0] a_reg, b_reg;
    reg signed [15:0] c_reg;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset state
            a_reg   <= 0;
            b_reg   <= 0;
            c_reg   <= 0;
            a_out   <= 0;
            b_out   <= 0;
            c_out   <= 0;
        end else begin
            // Perform the MAC operation
            // The new partial sum is the one we received, plus our new multiplication
            c_reg <= c_in + (a_in * b_in);
            
            // Pass the inputs to the next PE in the next cycle
            a_reg <= a_in;
            b_reg <= b_in;

            // Output the values we just processed/registered
            a_out <= a_reg;
            b_out <= b_reg;
            c_out <= c_reg;
        end
    end

endmodule