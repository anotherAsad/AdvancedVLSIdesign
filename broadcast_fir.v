module broadcast_fir_full_nopipeline(
	output wire [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	integer i;
	reg [31:0] multiplier [0:`FILTER_SIZE-1];		// 0..171 -> 0..85
	reg [15:0] adder [0:`FILTER_SIZE-1];

	// uses compile-time parametrized synthesis direction.
	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE; i+=1) begin
			if(reset)
				{multiplier[i], adder[i]} <= 48'd0;
			else if(en) begin
				// multipliers. HEED: blocking assignment
				multiplier[i]  = $signed(coeff_broadcaster.fir_coeff[`FILTER_SIZE-1-i]) * $signed(data_in);
				// adders
				if(i == 0)
					adder[i] <= multiplier[i][30-:16];
				else
					adder[i] <= multiplier[i][30-:16] + adder[i-1];
			end
		end
	end

	assign data_out = adder[`FILTER_SIZE-1];
endmodule

module broadcast_fir_full(
	output wire [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	integer i;
	reg [31:0] multiplier [0:`FILTER_SIZE-1];		// 0..171 -> 0..85
	reg [15:0] adder [0:`FILTER_SIZE-1];

	// uses compile-time parametrized synthesis direction.
	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE; i+=1) begin
			if(reset)
				{multiplier[i], adder[i]} <= 48'd0;
			else if(en) begin
				// multipliers.
				multiplier[i] <= $signed(coeff_broadcaster.fir_coeff[`FILTER_SIZE-1-i]) * $signed(data_in);
				// adders
				if(i == 0)
					adder[i] <= multiplier[i][30-:16];
				else
					adder[i] <= multiplier[i][30-:16] + adder[i-1];
			end
		end
	end

	assign data_out = adder[`FILTER_SIZE-1];
endmodule

module broadcast_fir_half(
	output wire [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	parameter xfr_func_idx = 0;

	integer i;
	reg [31:0] multiplier [0:`FILTER_SIZE/2-1];		// 0..171 -> 0..85
	reg [15:0] adder [0:`FILTER_SIZE/2-1];

	reg [15:0] coeff[0:`FILTER_SIZE/2-1];
		
	// Expect compile time synthesis
	always @(*) begin
		for(i=0; i<`FILTER_SIZE/2; i=i+1) begin
			case(xfr_func_idx)
				0: coeff[i] = coeff_broadcaster.fir_coeff[i*2+0];
				1: coeff[i] = coeff_broadcaster.fir_coeff[i*2+0] + coeff_broadcaster.fir_coeff[i*2+1];
				2: coeff[i] = coeff_broadcaster.fir_coeff[i*2+1];
				default : coeff[i] = 0;
			endcase
		end
	end

	// uses compile-time parametrized synthesis direction.
	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE/2; i+=1) begin
			if(reset)
				{multiplier[i], adder[i]} <= 48'd0;
			else if(en) begin
				// multiplier
				multiplier[i] <= $signed(coeff[`FILTER_SIZE/2-1-i]) * $signed(data_in);
				// adder
				if(i == 0)
					adder[i] <= multiplier[i][30-:16];
				else
					adder[i] <= multiplier[i][30-:16] + adder[i-1];
			end
		end
	end

	assign data_out = adder[`FILTER_SIZE/2-1];
endmodule


module broadcast_fir_onethird(
	output wire [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, clk, reset
);
	parameter xfr_func_idx = 0;

	integer i;
	reg [31:0] multiplier [0:`FILTER_SIZE/3-1];		// 0..203 -> 0..67
	reg [15:0] adder [0:`FILTER_SIZE/3-1];

	reg [15:0] coeff [0:`FILTER_SIZE/3-1];

	always @(*) begin
		for(i=0; i<`FILTER_SIZE/3; i+=1) begin
			// parametrized coeff select
			case(xfr_func_idx)
				0: coeff[i] = coeff_broadcaster.fir_coeff[i*3+0];
				1: coeff[i] = coeff_broadcaster.fir_coeff[i*3+1];
				2: coeff[i] = coeff_broadcaster.fir_coeff[i*3+2];
				3: coeff[i] = coeff_broadcaster.fir_coeff[i*3+0] + coeff_broadcaster.fir_coeff[i*3+1];
				4: coeff[i] = coeff_broadcaster.fir_coeff[i*3+1] + coeff_broadcaster.fir_coeff[i*3+2];
				5: coeff[i] = coeff_broadcaster.fir_coeff[i*3+0] + coeff_broadcaster.fir_coeff[i*3+1] + coeff_broadcaster.fir_coeff[i*3+2];
				default : coeff[i] = 0;
			endcase
		end
	end

	// uses compile-time parametrized synthesis direction.
	always @(posedge clk) begin
		for(i=0; i<`FILTER_SIZE/3; i+=1) begin
			if(reset)
				{multiplier[i], adder[i]} <= 48'd0;
			else if(en) begin
				// multipliers.
				multiplier[i] <= $signed(coeff[`FILTER_SIZE/3-1-i]) * $signed(data_in);
				// adders
				if(i == 0)
					adder[i] <= multiplier[i][30-:16];
				else
					adder[i] <= multiplier[i][30-:16] + adder[i-1];
			end
		end
	end

	assign data_out = adder[`FILTER_SIZE/3-1];
endmodule