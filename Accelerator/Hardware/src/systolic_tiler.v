module systolic_tiler_6x6 (
    input clk,
    input rst_n, // Active low reset
    input start,
    
    // We pass the entire 6x6 matrices as flattened input for simplicity
    // In a real chip, this would be an AXI Memory Interface
    input signed [7:0] A_flat_0,  A_flat_1,  A_flat_2,  A_flat_3,  A_flat_4,  A_flat_5,
    // ... (This input list would be huge, so we use internal memory for the demo)
    
    output reg done,
    output reg signed [15:0] result_check // Debug port to see a value
);

    // --- 1. MEMORY DEFINITION (6x6 Matrices) ---
    reg signed [7:0] A_MEM [0:5][0:5];
    reg signed [7:0] B_MEM [0:5][0:5];
    reg signed [15:0] C_MEM [0:5][0:5];

    // --- 2. TILING STATE MACHINE ---
    // We need to calculate 4 result blocks (C00, C01, C10, C11)
    // Each result block needs 2 accumulation steps (K=0, K=1)
    
    reg [1:0] row_blk; // 0 to 1
    reg [1:0] col_blk; // 0 to 1
    reg [1:0] k_blk;   // 0 to 1
    
    // Counters for feeding data (systolic skew)
    reg [4:0] feed_counter; 
    
    // --- 3. CONNECTIONS TO 3x3 ARRAY ---
    reg  sys_rst;
    reg  signed [7:0] a0, a1, a2;
    reg  signed [7:0] b0, b1, b2;
    wire signed [15:0] c00, c01, c02, c10, c11, c12, c20, c21, c22;
    
    systolic_array_3x3 core (
        .clk(clk), .rst(sys_rst),
        .a0(a0), .a1(a1), .a2(a2),
        .b0(b0), .b1(b1), .b2(b2),
        .c00(c00), .c01(c01), .c02(c02),
        .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );

    // State definitions
    localparam IDLE      = 0;
    localparam RESET_ARR = 1;
    localparam FEED_TILE = 2;
    localparam WAIT_OP   = 3;
    localparam SAVE_TILE = 4;
    localparam NEXT_BLK  = 5;
    localparam DONE      = 6;
    
    reg [3:0] state;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_blk <= 0; col_blk <= 0; k_blk <= 0;
            feed_counter <= 0;
            done <= 0;
            sys_rst <= 1;
            
            // Initialize memory with test data (Identity for B)
            // A = Count up, B = Identity
            for(i=0; i<6; i=i+1) begin
                for(j=0; j<6; j=j+1) begin
                    A_MEM[i][j] <= (i*6) + j + 1; // 1 to 36
                    B_MEM[i][j] <= (i==j) ? 1 : 0; // Identity
                    C_MEM[i][j] <= 0;
                end
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= RESET_ARR;
                        row_blk <= 0; col_blk <= 0; k_blk <= 0;
                        done <= 0;
                    end
                end

                // Reset the systolic array core (clears accumulators)
                // Only do this when starting a NEW C block (when k_blk == 0)
                RESET_ARR: begin
                    sys_rst <= 1;
                    state <= FEED_TILE;
                    feed_counter <= 0;
                end

                // Feed 3x3 Tile data with skew
                FEED_TILE: begin
                    sys_rst <= 0;
                    feed_counter <= feed_counter + 1;
                    
                    // We feed for approx 10 cycles to cover the diagonal skew
                    if (feed_counter < 10) begin
                        // LOGIC: Select data from large memory based on blocks
                        // Row Offset = row_blk*3, Col Offset = k_blk*3 for A
                        
                        // Row 0 of tile (skew 0)
                        a0 <= (feed_counter >= 0 && feed_counter < 3) ? A_MEM[row_blk*3 + 0][k_blk*3 + (feed_counter-0)] : 0;
                        // Row 1 of tile (skew 1)
                        a1 <= (feed_counter >= 1 && feed_counter < 4) ? A_MEM[row_blk*3 + 1][k_blk*3 + (feed_counter-1)] : 0;
                        // Row 2 of tile (skew 2)
                        a2 <= (feed_counter >= 2 && feed_counter < 5) ? A_MEM[row_blk*3 + 2][k_blk*3 + (feed_counter-2)] : 0;

                        // Same skew logic for B
                        // Row Offset = k_blk*3, Col Offset = col_blk*3 for B
                        b0 <= (feed_counter >= 0 && feed_counter < 3) ? B_MEM[k_blk*3 + (feed_counter-0)][col_blk*3 + 0] : 0;
                        b1 <= (feed_counter >= 1 && feed_counter < 4) ? B_MEM[k_blk*3 + (feed_counter-1)][col_blk*3 + 1] : 0;
                        b2 <= (feed_counter >= 2 && feed_counter < 5) ? B_MEM[k_blk*3 + (feed_counter-2)][col_blk*3 + 2] : 0;
                    end else begin
                        state <= WAIT_OP;
                        feed_counter <= 0;
                        // Stop inputs
                        a0<=0; a1<=0; a2<=0; b0<=0; b1<=0; b2<=0;
                    end
                end

                // Wait for pipeline to drain/settle
                WAIT_OP: begin
                    feed_counter <= feed_counter + 1;
                    if (feed_counter > 5) begin
                        // Determine next step
                        if (k_blk == 1) begin
                            // We finished all accumulations for this C block
                            state <= SAVE_TILE;
                        end else begin
                            // We need to accumulate the next tile part (A01 * B10)
                            // Do NOT reset array, just feed next data
                            k_blk <= k_blk + 1;
                            state <= FEED_TILE; 
                            feed_counter <= 0;
                        end
                    end
                end

                // Read results from array and put into C_MEM
                SAVE_TILE: begin
                    // Base offsets
                    C_MEM[row_blk*3 + 0][col_blk*3 + 0] <= c00;
                    C_MEM[row_blk*3 + 0][col_blk*3 + 1] <= c01;
                    C_MEM[row_blk*3 + 0][col_blk*3 + 2] <= c02;
                    
                    C_MEM[row_blk*3 + 1][col_blk*3 + 0] <= c10;
                    C_MEM[row_blk*3 + 1][col_blk*3 + 1] <= c11;
                    C_MEM[row_blk*3 + 1][col_blk*3 + 2] <= c12;
                    
                    C_MEM[row_blk*3 + 2][col_blk*3 + 0] <= c20;
                    C_MEM[row_blk*3 + 2][col_blk*3 + 1] <= c21;
                    C_MEM[row_blk*3 + 2][col_blk*3 + 2] <= c22;
                    
                    state <= NEXT_BLK;
                end

                // Move to next C block
                NEXT_BLK: begin
                    k_blk <= 0; // Reset K for new block
                    
                    if (col_blk == 0) begin
                        col_blk <= 1;
                        state <= RESET_ARR; // Must clear accumulators for new C block
                    end else if (row_blk == 0) begin
                        col_blk <= 0;
                        row_blk <= 1;
                        state <= RESET_ARR;
                    end else begin
                        state <= DONE; // Finished 6x6
                    end
                end
                
                DONE: begin
                    done <= 1;
                    result_check <= C_MEM[5][5]; // Output last value for debug

                    if (!start) begin
                        state <= IDLE; 
                    end
                end
            endcase
        end
    end

endmodule