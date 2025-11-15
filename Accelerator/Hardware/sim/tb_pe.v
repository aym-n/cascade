`timescale 1ns/1ps

module tb_pe;

	// Testbench signals
	reg clk;
	reg rst;
	reg signed [7:0] a_in;
	reg signed [7:0] b_in;
	reg signed [15:0] c_in;

	wire signed [7:0] a_out;
	wire signed [7:0] b_out;
	wire signed [15:0] c_out;

	// Instantiate the processing element under test
	processing_element uut (
		.clk(clk),
		.rst(rst),
		.a_in(a_in),
		.b_in(b_in),
		.c_in(c_in),
		.a_out(a_out),
		.b_out(b_out),
		.c_out(c_out)
	);

	// Clock generation: 10 ns period
	initial clk = 0;
	always #5 clk = ~clk;

	// Simple stimulus/check task
	task apply_and_check;
		input signed [7:0] ta;
		input signed [7:0] tb;
		input signed [15:0] tc;
		input signed [15:0] expected;
		begin
			// Drive inputs (sampled on next rising edge)
			a_in = ta;
			b_in = tb;
			c_in = tc;

			// Wait two clocks: one to compute internal registers, second to update outputs
			@(posedge clk);
			@(posedge clk);
			#1;

			if (c_out !== expected) begin
				$display("%0t: FAIL a=%0d b=%0d c_in=%0d => c_out=%0d (expected %0d)", $time, ta, tb, tc, c_out, expected);
			end else begin
				$display("%0t: PASS a=%0d b=%0d c_in=%0d => c_out=%0d", $time, ta, tb, tc, c_out);
			end
		end
	endtask

	// Test sequence
	initial begin
		// Waveform dump
		$dumpfile("tb_pe.vcd");
		$dumpvars(0, tb_pe);

		// Initialize
		rst = 1;
		a_in = 0;
		b_in = 0;
		c_in = 0;

		// Hold reset for a couple of cycles
		#20;
		rst = 0;

		// Wait for outputs to settle after reset
		@(posedge clk);

		$display("Starting PE tests");

		// Apply test vectors. expected = c_in + a_in * b_in
		// Use plain integer constants for portability with iverilog parsing
		apply_and_check(2,    3,   100, 106);
		apply_and_check(-4,   5,   10,  -10);
		apply_and_check(127,  1,   0,   127);
		apply_and_check(-128, 1,   0,   -128);
		apply_and_check(10,   -10, -50, -150);

		$display("All tests applied. Finishing simulation.");
		#20;
		$finish;
	end

endmodule

