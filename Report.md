# In-depth Report: Matrix Multiplication Acceleration with a Systolic Array Architecture

## 1. Introduction

This report provides a detailed technical analysis of the systolic array architecture for matrix multiplication acceleration, based on the Verilog source code and testbenches found in this project. Systolic arrays represent a powerful paradigm for parallel processing, particularly well-suited for the compute-intensive, regular dataflow of matrix multiplication—a cornerstone of modern deep learning, scientific computing, and signal processing workloads.

The architecture implemented in this project demonstrates a scalable and resource-efficient approach. It utilizes a compact, fixed-size 3x3 systolic array as a core processing engine and employs a sophisticated tiling mechanism to handle the multiplication of larger 6x6 matrices, showcasing a practical design for real-world applications where hardware resources are finite.

## 2. Core Component: The Processing Element (PE)

The fundamental building block of the systolic array is the Processing Element (PE), defined in `pe.v`. Its simplicity is key to the scalability of the entire architecture.

### Functionality & Implementation

Each PE is a sequential arithmetic unit designed to perform a single Multiply-Accumulate (MAC) operation per clock cycle. Its Verilog implementation reveals its three primary functions:

1.  **Multiplication:** It multiplies its two signed 8-bit inputs, `a_in` and `b_in`.
2.  **Accumulation:** It adds the product to an internal 16-bit register, `c_result`. This register accumulates values over multiple cycles, which is essential for the matrix multiplication algorithm.
3.  **Data Propagation:** It passes the `a_in` and `b_in` values to its outputs, `a_out` and `b_out`, on the following clock cycle. This registered output is what enables the "systolic" movement of data through the array.

```verilog
// From: src/pe.v
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
```

The use of an active-high synchronous reset (`rst`) ensures that all PEs can be cleared to a known state simultaneously. The bit-widths indicate that the array handles 8-bit signed inputs, producing a 16-bit accumulated result, a common requirement for neural network computations.

### Waveform Analysis (`tb_pe_demo.v`)

When analyzing the PE's behavior in a waveform viewer like GTKWave, we expect to see the following:
*   On the rising edge of `clk` after `rst` is de-asserted, `a_out` and `b_out` will take on the values that `a_in` and `b_in` had just before the clock edge.
*   The `c_result` register will update on the clock edge, adding the product of the *current* `a_in` and `b_in` to its previous value.
*   For example, if at T=0, `a_in=2`, `b_in=3`, and `c_result=0`, then at T=1 (after the clock edge), `c_result` will become 6. If at T=1, `a_in=4`, `b_in=5`, then at T=2, `c_result` will become `6 + (4*5) = 26`.

***
<p align="center">
  [Placeholder for Image: Waveform showing a_in, b_in, a_out, b_out, and c_result over several clock cycles]
</p>
***

## 3. The Systolic Array Architecture

The `systolic_array_3x3.v` module instantiates a 3x3 grid of PEs to form the computational core.

### Dataflow: Output-Stationary

The array implements an **output-stationary** dataflow. This means that the partial sums that will eventually form the output matrix `C` remain stationary within the `c_result` register of a specific PE, while the input matrices `A` and `B` are streamed through the array.

*   **Matrix A:** Values from matrix A are fed into the top row of PEs and propagate vertically downwards.
*   **Matrix B:** Values from matrix B are fed into the leftmost column of PEs and propagate horizontally to the right.

### Input Skewing

To ensure that the correct elements `A[i][k]` and `B[k][j]` meet at the PE responsible for calculating `C[i][j]`, the input data streams must be skewed in time. This is explicitly demonstrated in the `run_systolic_pulse` task within `tb_systolic_array.v`.

*   `a0` (for column 0 of PEs) starts at time `t=0`.
*   `a1` (for column 1 of PEs) starts at time `t=1`.
*   `a2` (for column 2 of PEs) starts at time `t=2`.

A similar skew is applied to the `b` inputs. This diamond-shaped wavefront of data ensures that the partial products are calculated correctly at each PE. For a 3x3 multiplication, element `C[2][2]` begins its final accumulation `(3*3)-1 = 8` clock cycles after the first inputs are fed.

### Waveform Analysis (`tb_systolic_array.v`)

In the waveform for the 3x3 array testbench, we should observe:
*   The staggered application of inputs `a0, a1, a2` and `b0, b1, b2` according to the skewing logic in the `run_systolic_pulse` task.
*   After the initial pipeline latency (around 7-8 cycles), the output signals (`c00` through `c22`) will begin to show their final, stable values.
*   The `c` values will remain constant until the next `rst` pulse, confirming the output-stationary nature of the design.

***
<p align="center">
  [Placeholder for Image: Waveform showing the skewed inputs and the resulting stable 'c' outputs of the 3x3 array]
</p>
***

## 4. Tiling for Larger Matrices

A fixed-size 3x3 hardware array cannot natively multiply larger matrices. The `systolic_tiler_6x6.v` module addresses this by implementing a tiling algorithm, breaking the larger 6x6 matrix multiplication into a series of 3x3 operations.

### Tiling Process and State Machine

The module partitions the 6x6 input matrices A and B into four 3x3 tiles each (A00, A01, A10, A11 and B00, B01, B10, B11). It then computes the four 3x3 tiles of the output matrix C. For example, the calculation for the top-left tile `C00` is:
`C00 = (A00 * B00) + (A01 * B10)`

This complex process is orchestrated by a finite state machine (FSM):
*   **`IDLE`**: Waits for a `start` signal.
*   **`RESET_ARR`**: Asserts the systolic array's reset. This is crucial at the beginning of a *new* output tile calculation (when `k_blk == 0`) to clear the PEs' accumulators.
*   **`FEED_TILE`**: Streams a pair of 3x3 tiles (e.g., A00 and B00) into the array with the required skewing. This state lasts for 10 clock cycles to ensure the entire tile is fed.
*   **`WAIT_OP`**: Waits for 6 cycles for the last computation to drain from the array's pipeline.
*   **`SAVE_TILE`**: If all accumulations for an output tile are complete (`k_blk == 1`), the results from the array's `c` outputs are read and stored in the appropriate block of `C_MEM`.
*   **`NEXT_BLK`**: Increments the block counters (`row_blk`, `col_blk`) to move to the next output tile.
*   **`DONE`**: Asserts the `done` signal once all 4 output tiles have been computed.

The tiler cleverly avoids resetting the array between accumulations (e.g., after `A00*B00` is done but before `A01*B10` begins), allowing the results to build up correctly in the PEs.

### Waveform Analysis (`tb_tiling.v`)

The waveform for the tiling testbench is more complex and reveals the high-level control logic:
*   The `state` register of the FSM should cycle through the states (`IDLE`, `RESET_ARR`, `FEED_TILE`, etc.) in a predictable sequence.
*   The `start` signal will initiate the process, and the `done` signal should go high after all tiles are computed.
*   The block counters (`row_blk`, `col_blk`, `k_blk`) will increment as the tiler moves through its main loops.
*   The `sys_rst` signal to the core array will pulse high only when `k_blk` is 0, demonstrating the selective reset required for accumulation.
*   Observing the `uut.C_MEM` values in the simulator will show them being written tile by tile at the end of each `SAVE_TILE` state.

***
<p align="center">
  [Placeholder for Image: Waveform showing the tiler's FSM states, start/done signals, and block counters]
</p>
***

## 5. Performance Analysis

*   **3x3 Array Latency**: The time from when the first inputs (`a0`, `b0`) are applied until the last output (`c22`) is valid. Based on the dataflow, this is `2*N - 2 = 2*3 - 2 = 4` cycles for the pipeline to fill. The testbench (`tb_systolic_array.v`) waits a conservative 20 cycles before checking the results.
*   **6x6 Tiler Latency**: The total time to compute a 6x6 matrix multiplication is dominated by the 8 separate 3x3 multiplications. Each 3x3 multiplication (feed + wait) takes approximately `10 + 6 = 16` cycles. For 8 multiplications, this is roughly `8 * 16 = 128` cycles, plus the overhead for saving and resetting states. This parallel architecture is significantly faster than a purely sequential approach, which would require `6*6*6 = 216` MAC operations.

## 6. Simulation and Verification

The project includes two robust testbenches for verification:
*   `tb_systolic_array.v`: A unit test for the 3x3 array. It runs two tests: one with an identity matrix to verify basic dataflow and one with random values to test general correctness.
*   `tb_tiling.v`: A top-level integration test for the 6x6 tiling module. It comprehensively validates the FSM and memory logic with three distinct test cases:
    1.  **Identity Matrix**: Verifies the correctness of the tiling and accumulation logic.
    2.  **Constant Values**: Checks that accumulation works correctly across multiple tiles.
    3.  **Full Random**: A stressful test with signed random numbers to catch edge cases.

The use of `$dumpfile` allows for detailed waveform analysis in tools like GTKWave, which is essential for debugging timing-sensitive hardware designs.

## 7. Conclusion

This project successfully implements a scalable and efficient systolic array for matrix multiplication in Verilog. The design demonstrates a clear understanding of hardware architecture principles.

*   **Key Strengths**:
    *   **Modularity**: A clean separation between the PE, the array, and the tiler.
    *   **Scalability**: The tiling mechanism is a practical solution for handling large problems with limited hardware resources.
    *   **Efficiency**: The systolic dataflow achieves high parallelism, offering a significant performance boost for matrix multiplication.

*   **Potential Future Work**:
    *   **FPGA Synthesis and Implementation**: Synthesize the design for a specific FPGA target (e.g., Xilinx Artix-7 or Intel Cyclone V) to analyze resource utilization (LUTs, DSPs, BRAMs), and determine the maximum achievable clock frequency (Fmax).
    *   **Hardware Driver Development**: Develop software drivers (e.g., in C/C++ for a Linux environment) to control the accelerator. This would involve writing to memory-mapped control registers to start the computation and reading results from the output memory block.
    *   **AXI4-Stream Interface**: Replace the simple parallel inputs with an industry-standard AXI4-Stream interface to allow for easier integration into larger Systems-on-a-Chip (SoCs).
    *   **Parameterization**: Convert the modules to use Verilog parameters for array dimensions (e.g., `parameter N = 3`), allowing the same code to generate systolic arrays of different sizes.
    *   **Variable Precision**: Introduce support for different data types (e.g., 16-bit floats, bfloat16) to extend the applicability of the accelerator.
