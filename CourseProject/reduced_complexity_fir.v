
// Exploits symmetry to use half the amount of multipliers. Designed as broadcast fir. Exhibits L1 pipelining.
module reduced_complexity_fir_full(
	output wire [23:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	integer i;
	reg signed [31:0] multiplier [0:`FILTER_SIZE/2-1];		// 0..171 -> 0..85
	reg signed [23:0] adder [0:`FILTER_SIZE-1];

	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE/2; i+=1) begin
			if(reset)
				multiplier[i] <= 32'd0;
			else if(en) begin
				// multipliers
				multiplier[i] <= $signed(coeff_broadcaster.fir_coeff[`FILTER_SIZE-1-i]) * $signed(data_in);
			end
		end
	end

	// uses compile-time parametrized synthesis direction.
	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE; i+=1) begin
			if(reset)
				adder[i] <= 24'd0;
			else if(en) begin
				if(i == 0)
					adder[i] <= $signed(multiplier[i][30-:16]);
				else if(i < `FILTER_SIZE/2)
					adder[i] <= $signed(multiplier[i][30-:16]) + $signed(adder[i-1]);
				else
					adder[i] <= $signed(multiplier[`FILTER_SIZE-i-1][30-:16]) + $signed(adder[i-1]);
			end
		end			
	end

	assign data_out = adder[`FILTER_SIZE-1];
endmodule