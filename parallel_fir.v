
module FIRimpl_L2parallel(
	output reg  [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, reset,
	input  wire clk, clk_serial
);
	// serdes layout
	reg  toggle;
	reg  [15:0] data_in_0, data_in_1;

	always @(posedge clk_serial) begin
		if(reset)
			{toggle, data_in_0, data_in_1} <= 33'd0;
		else if(en) begin
			toggle <= ~toggle;

			if(~toggle)
				data_in_0 <= data_in;
			else
				data_in_1 <= data_in;
		end
	end

	// parallel part.
	wire [15:0] data_out_H0, data_out_H1, data_out_H0_H1;
	wire [15:0] data_in_H0, data_in_H1, data_in_H0_H1;
	
	assign data_in_H0 = data_in_0;
	assign data_in_H1 = data_in_1;
	assign data_in_H0_H1 = data_in_0 + data_in_1;

	broadcast_fir_half #(0) FIR_H0(
		.data_out(data_out_H0),
		.data_in(data_in_H0),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_half #(1) FIR_H0_H1(
		.data_out(data_out_H0_H1),
		.data_in(data_in_H0_H1),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_half #(2) FIR_H1(
		.data_out(data_out_H1),
		.data_in(data_in_H1),
		.en(en),
		.clk(clk), .reset(reset)
	);

	// recombination
	reg  [15:0] H1_out_delay;

	always @(posedge clk) begin
		if(reset)
			H1_out_delay <= 1'b0;
		else
			H1_out_delay <= data_out_H1;
	end

	wire [15:0] data_out_0 = data_out_H0 + H1_out_delay;
	wire [15:0] data_out_1 = data_out_H0_H1 - data_out_H1 - data_out_H0;

	// parallel to serial
	always @(posedge clk_serial) begin
		if(reset)
			data_out <= 16'd0;
		else if(en) begin
			if(toggle)
				data_out <= data_out_0;
			else
				data_out <= data_out_1;
		end
	end
endmodule

module FIRimpl_L3parallel(
	output reg  [15:0] data_out,
	input  wire [15:0] data_in,
	input  wire en, reset,
	input  wire clk, clk_serial
);
	// serdes layout
	reg  [01:0] toggle;
	reg  [15:0] data_in_0, data_in_1, data_in_2;

	always @(posedge clk_serial) begin
		if(reset)
			{toggle, data_in_0, data_in_1, data_in_2} <= {2'd0, 48'd0};
		else if(en) begin
			toggle <= (toggle == 2'd2) ? 2'd0: toggle + 2'd1;

			case(toggle)
				0: data_in_0 <= data_in;
				1: data_in_1 <= data_in;
				2: data_in_2 <= data_in;
				default: {data_in_0, data_in_1, data_in_2} <= 48'd0;
			endcase
		end
	end

	// parallel part.
	wire [15:0] data_out_H0, data_out_H1, data_out_H2, data_out_H0_H1, data_out_H1_H2, data_out_H0_H1_H2;
	wire [15:0] data_in_H0, data_in_H1, data_in_H2, data_in_H0_H1, data_in_H1_H2, data_in_H0_H1_H2;
	
	assign data_in_H0 = data_in_0;
	assign data_in_H1 = data_in_1;
	assign data_in_H2 = data_in_2;
	assign data_in_H0_H1 = data_in_0 + data_in_1;
	assign data_in_H1_H2 = data_in_1 + data_in_2; 
	assign data_in_H0_H1_H2 = data_in_H0_H1 + data_in_2; 

	broadcast_fir_onethird #(0) FIR_H0(
		.data_out(data_out_H0),
		.data_in(data_in_H0),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_onethird #(1) FIR_H1(
		.data_out(data_out_H1),
		.data_in(data_in_H1),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_onethird #(2) FIR_H2(
		.data_out(data_out_H2),
		.data_in(data_in_H2),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_onethird #(3) FIR_H0_H1(
		.data_out(data_out_H0_H1),
		.data_in(data_in_H0_H1),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_onethird #(4) FIR_H1_H2(
		.data_out(data_out_H1_H2),
		.data_in(data_in_H1_H2),
		.en(en),
		.clk(clk), .reset(reset)
	);

	broadcast_fir_onethird #(5) FIR_H0_H1_H2(
		.data_out(data_out_H0_H1_H2),
		.data_in(data_in_H0_H1_H2),
		.en(en),
		.clk(clk), .reset(reset)
	);

	reg  [15:0] H2_delayed;
	wire [15:0] H0_minus_H2D = (data_out_H0 -  H2_delayed);
	wire [15:0] H0_H1_minus_H1 = data_out_H0_H1 - data_out_H1;
	wire [15:0] H1_H2_minus_H1 = data_out_H1_H2 - data_out_H1;
	reg  [15:0] H1_H2_minus_H1_d;

	wire [15:0] data_out_0 = H0_minus_H2D + H1_H2_minus_H1_d;
	wire [15:0] data_out_1 = H0_H1_minus_H1 - H0_minus_H2D;
	wire [15:0] data_out_2 = data_out_H0_H1_H2 - H0_H1_minus_H1 - H1_H2_minus_H1;

	// parallel to serial
	always @(posedge clk_serial) begin
		if(reset)
			data_out <= 16'd0;
		else if(en) begin
			case(toggle)
				0: data_out <= data_out_2;
				1: data_out <= data_out_0;
				2: data_out <= data_out_1;
				default: data_out <= 16'd0;
			endcase
		end
	end

	// delay section
	always @(posedge clk) begin
		if(reset)
			{H2_delayed, H1_H2_minus_H1_d} <= 'd0;
		else if(en) begin
			H2_delayed <= data_out_H2;
			H1_H2_minus_H1_d <= H1_H2_minus_H1;
		end
	end
endmodule
