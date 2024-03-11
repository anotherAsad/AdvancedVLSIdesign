module directform_fir_full(
	output wire [23:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	integer i;
	reg [15:0] delay_line [0:`FILTER_SIZE-1];
	
	reg signed [31:0] multiplier [0:`FILTER_SIZE-1];		// 0..171 -> 0..85
	reg signed [23:0] adder [0:`FILTER_SIZE-1];

	always @(*) delay_line[0] = data_in;

	always @(posedge clk) begin
		for(i = 0; i < `FILTER_SIZE; i += 1) begin
			if(reset) begin
				if(i != 0)
					delay_line[i] <= 16'd0;
				{multiplier[i], adder[i]} <= 64'd0;
			end
			else if(en) begin
				if(i != 0)
					delay_line[i] <= delay_line[i-1];

				multiplier[i] <= $signed(delay_line[i]) * $signed(coeff_broadcaster.fir_coeff[i]);

				// HEED: blocking assignment.
				if(i == 0)
					adder[i] = $signed(multiplier[i][30-:16]);
				else
					adder[i] = $signed(adder[i-1]) + $signed(multiplier[i][30-:16]);
			end
		end
	end

	assign data_out = adder[`FILTER_SIZE-1];
endmodule

// fine-grained pipelining of the final adder
module directform_fir_full_pipelined(
	output wire [23:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	integer i;
	reg [15:0] delay_line [0:`FILTER_SIZE-1];
	reg [31:0] multiplier [0:`FILTER_SIZE-1];		// 0..171 -> 0..85

	always @(*) delay_line[0] = data_in;

	always @(posedge clk) begin
		for(i = 0; i < `FILTER_SIZE; i += 1) begin
			if(reset) begin
				if(i != 0)
					delay_line[i] <= 16'd0;
				multiplier[i] <= 32'd0;
			end
			else if(en) begin
				if(i != 0)
					delay_line[i] <= delay_line[i-1];

				multiplier[i] <= $signed(delay_line[i]) * $signed(coeff_broadcaster.fir_coeff[i]);
			end
		end
	end

	reg signed [19:0] adder_out_stage_1 [0:`FILTER_SIZE/2-1];		// 0..101
	reg signed [20:0] adder_out_stage_2 [0:`FILTER_SIZE/4-1];		// 0..50
	reg signed [21:0] adder_out_stage_3 [0:`FILTER_SIZE/8-0];		// 0..25. One extra adder for the straggler
	reg signed [22:0] adder_out_stage_4 [0:`FILTER_SIZE/16];		// 0..12
	reg signed [23:0] adder_out;

	always @(posedge clk) begin
		// stage 1
		for(i=0; i<`FILTER_SIZE/2; i+=1) begin		// fin val is 102-1 = 101
			if(reset)
				adder_out_stage_1[i] <= 16'd0;
			else if(en) begin
				adder_out_stage_1[i] <= $signed(multiplier[2*i][30-:16]) + $signed(multiplier[2*i+1][30-:16]);
			end
		end

		// stage 2
		for(i=0; i<`FILTER_SIZE/4; i+=1) begin		// fin val is 51-1 = 50
			if(reset)
				adder_out_stage_2[i] <= 16'd0;
			else if(en) begin
				adder_out_stage_2[i] <= adder_out_stage_1[2*i] + adder_out_stage_1[2*i+1];
			end
		end

		// stage 3
		for(i=0; i<=`FILTER_SIZE/8; i+=1) begin		// fin val is 25-1 = 24. Covers till adder_out_stage_2[49]
			if(reset)
				adder_out_stage_3[i] <= 16'd0;
			else if(en) begin
				if(i==`FILTER_SIZE/8)
					adder_out_stage_3[i] <= adder_out_stage_2[i*2];		// [25] <= [50]
				else
					adder_out_stage_3[i] <= adder_out_stage_2[2*i] + adder_out_stage_2[2*i+1];
			end
		end

		// stage 4
		for(i=0; i<=`FILTER_SIZE/16; i+=1) begin		// fin val is 12. Covers till adder_out_stage_3[25]
			if(reset)
				adder_out_stage_4[i] <= 16'd0;
			else if(en) begin
				adder_out_stage_4[i] <= adder_out_stage_3[2*i] + adder_out_stage_3[2*i+1];
			end
		end

		// stage 5. One large unrolled adder with 13 operands. HEED: Blocking assignments.
		if(reset)
			adder_out = 16'd0;
		else if(en) begin
			adder_out = 0;
			// loop in all inputs
			for(i=0; i<=`FILTER_SIZE/16; i+=1)
				adder_out = adder_out + adder_out_stage_4[i];
		end
	end

	assign data_out = adder_out;
endmodule