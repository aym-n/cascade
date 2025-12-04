module conv_im2col (
    input clk,
    input rst_n,
    input start,
    output reg done,
    output reg signed [15:0] debug_out // Last value for checking
);

    // --- 1. MEMORY STORAGE ---
    // Image: 4x4 Input (Flattened to 16 bytes for simplicity)
    reg signed [7:0] IMG_MEM [0:15]; 
    
    // Weights: 3 Filters, each 2x2 (4 weights). Total 12 weights.
    // Organized as [Filter_ID][Weight_Index]
    reg signed [7:0] W_MEM [0:2][0:3];
    
    // Output: 3x3 Feature Map for 3 Filters (9 pixels * 3 channels)
    // Organized as [Output_Pixel_Index 0..8][Filter_ID 0..2]
    reg signed [15:0] OUT_MEM [0:8][0:2];

    // --- 2. TILING STATE MACHINE ---
    // We have 9 Output Pixels to compute.
    // The Array handles 3 Rows at a time.
    // So we need 3 Tiles (Passes): 
    // Tile 0: Pixels 0,1,2. Tile 1: Pixels 3,4,5. Tile 2: Pixels 6,7,8.
    
    reg [1:0] tile_idx; // 0, 1, 2
    reg [4:0] feed_counter;
    
    // Systolic Signals
    reg sys_rst;
    reg signed [7:0] a0, a1, a2, b0, b1, b2;
    wire signed [15:0] c00, c01, c02, c10, c11, c12, c20, c21, c22;

    systolic_array_3x3 core (
        .clk(clk), .rst(sys_rst),
        .a0(a0), .a1(a1), .a2(a2),
        .b0(b0), .b1(b1), .b2(b2),
        .c00(c00), .c01(c01), .c02(c02),
        .c10(c10), .c11(c11), .c12(c12),
        .c20(c20), .c21(c21), .c22(c22)
    );

    // FSM States
    localparam IDLE = 0, FEED = 1, WAIT = 2, SAVE = 3, NEXT = 4, FINISH = 5;
    reg [2:0] state;

    integer i;

    // --- 3. IM2COL ADDRESS GENERATION FUNCTION ---
    // Converts (Output_Pixel_ID, Kernel_Index) -> Input_Image_Address
    function [3:0] get_img_addr;
        input [3:0] out_px_idx; // 0 to 8
        input [2:0] k_idx;      // 0 to 3 (for 2x2 kernel)
        reg [1:0] out_y, out_x;
        reg [1:0] ker_y, ker_x;
        reg [3:0] final_y, final_x;
        begin
            // 1. Map Output Index to Spatial (Y, X)
            // Image is 4x4, Output is 3x3.
            out_y = out_px_idx / 3;
            out_x = out_px_idx % 3;
            
            // 2. Map Kernel Index to Spatial Offset (Ky, Kx)
            ker_y = k_idx / 2;
            ker_x = k_idx % 2;
            
            // 3. Add to get Input Image Coordinate
            final_y = out_y + ker_y;
            final_x = out_x + ker_x;
            
            // 4. Flatten to Address (Row * 4 + Col)
            get_img_addr = (final_y * 4) + final_x;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tile_idx <= 0;
            feed_counter <= 0;
            done <= 0;
            sys_rst <= 1;
            
            // Init Memory (Test Pattern)
            // Image: Count 0 to 15
            for(i=0; i<16; i=i+1) IMG_MEM[i] <= i;
            
            // Weights: Identity-ish
            // Filter 0: All 1s. Filter 1: First is 1. Filter 2: Last is 1.
            W_MEM[0][0]=1; W_MEM[0][1]=1; W_MEM[0][2]=1; W_MEM[0][3]=1; 
            W_MEM[1][0]=2; W_MEM[1][1]=0; W_MEM[1][2]=0; W_MEM[1][3]=0;
            W_MEM[2][0]=0; W_MEM[2][1]=0; W_MEM[2][2]=0; W_MEM[2][3]=3;
            
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if(start) begin
                        state <= FEED;
                        tile_idx <= 0;
                        sys_rst <= 1; // Reset Array
                    end
                end

                FEED: begin
                    sys_rst <= 0; // Release Reset
                    feed_counter <= feed_counter + 1;
                    
                    // We feed 4 kernel elements + Skew delay
                    if (feed_counter < 8) begin
                        // LOGIC: 
                        // Row 0 of Array = Output Pixel (tile_idx*3 + 0)
                        // Row 1 of Array = Output Pixel (tile_idx*3 + 1)
                        // Row 2 of Array = Output Pixel (tile_idx*3 + 2)
                        
                        // INPUT A (IMAGE): Apply im2col Address Logic + Skew
                        // Logic: [Row_Index][Kernel_Index]
                        // Note: Skew logic (feed_counter - row_idx) must be Valid Kernel Index (0..3)
                        
                        // Row 0 (Skew 0)
                        if (feed_counter >= 0 && feed_counter < 4)
                            a0 <= IMG_MEM[ get_img_addr((tile_idx*3)+0, feed_counter) ];
                        else a0 <= 0;

                        // Row 1 (Skew 1)
                        if (feed_counter >= 1 && feed_counter < 5)
                            a1 <= IMG_MEM[ get_img_addr((tile_idx*3)+1, feed_counter-1) ];
                        else a1 <= 0;

                        // Row 2 (Skew 2)
                        if (feed_counter >= 2 && feed_counter < 6)
                            a2 <= IMG_MEM[ get_img_addr((tile_idx*3)+2, feed_counter-2) ];
                        else a2 <= 0;

                        // INPUT B (WEIGHTS): 
                        // Col 0 = Filter 0, Col 1 = Filter 1...
                        // Add Vertical Skew
                        
                        // Filter 0 (Skew 0)
                        if (feed_counter >= 0 && feed_counter < 4)
                            b0 <= W_MEM[0][feed_counter];
                        else b0 <= 0;

                        // Filter 1 (Skew 1)
                        if (feed_counter >= 1 && feed_counter < 5)
                            b1 <= W_MEM[1][feed_counter-1];
                        else b1 <= 0;
                        
                        // Filter 2 (Skew 2)
                        if (feed_counter >= 2 && feed_counter < 6)
                            b2 <= W_MEM[2][feed_counter-2];
                        else b2 <= 0;

                    end else begin
                        state <= WAIT;
                        feed_counter <= 0;
                    end
                end
                
                WAIT: begin
                    // Wait for calculations to flush
                    feed_counter <= feed_counter + 1;
                    if(feed_counter > 4) state <= SAVE;
                end
                
                SAVE: begin
                    // Store Results for this Tile (3 output pixels)
                    // Output Pixel X, Filter Y
                    
                    OUT_MEM[tile_idx*3 + 0][0] <= c00; // Px 0, Filt 0
                    OUT_MEM[tile_idx*3 + 0][1] <= c01; // Px 0, Filt 1
                    OUT_MEM[tile_idx*3 + 0][2] <= c02; // Px 0, Filt 2
                    
                    OUT_MEM[tile_idx*3 + 1][0] <= c10;
                    OUT_MEM[tile_idx*3 + 1][1] <= c11;
                    OUT_MEM[tile_idx*3 + 1][2] <= c12;

                    OUT_MEM[tile_idx*3 + 2][0] <= c20;
                    OUT_MEM[tile_idx*3 + 2][1] <= c21;
                    OUT_MEM[tile_idx*3 + 2][2] <= c22;
                    
                    state <= NEXT;
                end
                
                NEXT: begin
                    if(tile_idx == 2) begin
                        state <= FINISH;
                    end else begin
                        tile_idx <= tile_idx + 1;
                        state <= FEED;
                        sys_rst <= 1; // Important: Reset accumulators for next set of pixels
                        feed_counter <= 0;
                    end
                end
                
                FINISH: begin
                    done <= 1;
                    debug_out <= OUT_MEM[0][0];
                    if(!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule