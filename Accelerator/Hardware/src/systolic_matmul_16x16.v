// Single-shot 16x16 matrix multiply controller (no tiling).
module systolic_matmul_16x16 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               start,
    output reg                done,
    output reg  signed [31:0] result_sum
);
    localparam N = 16;

    reg signed [7:0]  A_MEM [0:N-1][0:N-1];
    reg signed [7:0]  B_MEM [0:N-1][0:N-1];
    reg signed [15:0] C_MEM [0:N-1][0:N-1];

    reg               sys_rst;
    reg signed [7:0]  a_feed [0:N-1];
    reg signed [7:0]  b_feed [0:N-1];
    wire signed [15:0] c_pe  [0:N-1][0:N-1];

    systolic_array_16x16 core (
        .clk(clk),
        .rst(sys_rst),
        .a_in(a_feed),
        .b_in(b_feed),
        .c_out(c_pe)
    );

    localparam IDLE   = 0;
    localparam RESET  = 1;
    localparam FEED   = 2;
    localparam WAIT   = 3;
    localparam CAPTURE = 4;
    localparam FINISH = 5;

    reg [2:0] state;
    reg [7:0] feed_cnt;
    reg [7:0] wait_cnt;

    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            done     <= 0;
            sys_rst  <= 1;
            feed_cnt <= 0;
            wait_cnt <= 0;
            result_sum <= 0;

            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < N; j = j + 1) begin
                    A_MEM[i][j] <= (i * N) + j + 1;
                    B_MEM[i][j] <= (i == j) ? 8'sd1 : 8'sd0;
                    C_MEM[i][j] <= 16'sd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= RESET;
                    end
                end

                RESET: begin
                    sys_rst  <= 1;
                    feed_cnt <= 0;
                    wait_cnt <= 0;
                    state    <= FEED;
                end

                FEED: begin
                    sys_rst <= 0;
                    feed_cnt <= feed_cnt + 1;

                    for (i = 0; i < N; i = i + 1) begin
                        a_feed[i] <= (feed_cnt >= i && feed_cnt < i + N)
                            ? A_MEM[i][feed_cnt - i] : 8'sd0;
                    end
                    for (j = 0; j < N; j = j + 1) begin
                        b_feed[j] <= (feed_cnt >= j && feed_cnt < j + N)
                            ? B_MEM[feed_cnt - j][j] : 8'sd0;
                    end

                    if (feed_cnt >= (2 * N - 1)) begin
                        for (i = 0; i < N; i = i + 1) begin
                            a_feed[i] <= 8'sd0;
                            b_feed[i] <= 8'sd0;
                        end
                        state    <= WAIT;
                        wait_cnt <= 0;
                    end
                end

                WAIT: begin
                    wait_cnt <= wait_cnt + 1;
                    if (wait_cnt >= (2 * N - 1)) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    for (i = 0; i < N; i = i + 1) begin
                        for (j = 0; j < N; j = j + 1) begin
                            C_MEM[i][j] <= c_pe[i][j];
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    begin
                        reg signed [31:0] acc;
                        acc = 0;
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < N; j = j + 1) begin
                                acc = acc + C_MEM[i][j];
                            end
                        end
                        result_sum <= acc;
                    end
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
