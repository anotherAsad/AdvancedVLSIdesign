`default_nettype none
`define FILTER_SIZE 204

`include "coeff_broadcaster.v"

`include "broadcast_fir.v"
`include "reduced_complexity_fir.v"
`include "directform_fir.v"
`include "parallel_fir.v"

module testbench;
	integer i;

	wire [23:0] data_out_L2, data_out_L3;
	wire [23:0] data_out_baseline_direct, data_out_direct_log_pipelined;
	wire [23:0] data_out_baseline_symmetric, data_out_baseline_broadcast;
	reg  [15:0] data_in;
	reg  en, reset;
	reg  clk, clk_2x, clk_3x;

	reg  [15:0] data_in_cdc;

	// used for clock domain crossing for non-parallel filters. Shifts input data to slow domain.
	always @(posedge clk_2x) begin
		if(reset)
			data_in_cdc <= 16'd0;
		else
			data_in_cdc <= data_in;
	end

	FIRimpl_L2parallel FIRimpl_L2parallel_inst(
		.data_out(data_out_L2),
		.data_in(data_in),
		.en(en), .reset(reset),
		.clk_serial(clk_2x),
		.clk(clk)
	);

	FIRimpl_L3parallel FIRimpl_L3parallel_inst(
		.data_out(data_out_L3),
		.data_in(data_in),
		.en(en), .reset(reset),
		.clk_serial(clk_3x),
		.clk(clk)
	);

	directform_fir_full baseline_direct(
		.data_out(data_out_baseline_direct),
		.data_in(data_in_cdc),
		.en(en), .reset(reset),
		.clk(clk)
	);

	directform_fir_full_pipelined baseline_direct_pipelined(
		.data_out(data_out_direct_log_pipelined),
		.data_in(data_in_cdc),
		.en(en), .reset(reset),
		.clk(clk)
	);

	broadcast_fir_full baseline_broadcast(
		.data_out(data_out_baseline_broadcast),
		.data_in(data_in_cdc),
		.en(en), .reset(reset),
		.clk(clk)
	);

	reduced_complexity_fir_full baseline_reduced(
		.data_out(data_out_baseline_symmetric),
		.data_in(data_in_cdc),
		.en(en), .reset(reset),
		.clk(clk)
	);

	always @(posedge clk_3x) begin
		if(reset)
			i <= 0;
		else
			i <= i+1;
	end

	always @(*) begin
		if(i == 2)
			data_in = ~(16'd1 << 15);		// 0.999 in Q1.15
		else
			data_in = 0;
	end

	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, testbench);

		clk_2x = 0;
		clk_3x = 0;

		clk = 0;
		reset = 0;
		en = 0;
		data_in = 0;

		// reset sequence
		#1 reset = 1;
		#1 clk_3x = 1; clk_2x = 1; clk = 1;
		#1 clk_3x = 0; clk_2x = 0; clk = 0;
		#1 reset = 0;
		#1 en = 1;

		#1 clk_3x = 1; #0 clk_2x = 1; #0 clk = 1;

		repeat(1000) begin
			// action in 6 ut
			#2 clk_3x = ~clk_3x;
			#1 clk_2x = ~clk_2x;
			#1 clk_3x = ~clk_3x;
			#2 clk_3x = ~clk_3x;
			#0 clk_2x = ~clk_2x;
			#0 clk = ~clk;
		end
	end

endmodule
