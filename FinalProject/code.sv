`include "tables.sv"

`define W `N-`dropped_MSB		// length of the coded message.	
`define V `K-`dropped_MSB

module serial_bch_encoder(
	input  wire [`V-1:0] data_in,
	output wire [`W-1:0] codeword_out,
	output reg  busy,
	output reg  output_valid,
	input  wire kick_off,
	input  wire en, clk, reset
);
	wire [`N-`K-0:0] generator = 9'b111010001;
	reg  [`N-`K-1:0] LFSR;		// generator has 0 to N-K bits
	reg  [`M-1 :0] counter;		// runs from 0 .. `V-1. The whole length of the message.
	reg  [`V-1 :0] data_in_latched;

	wire last_input_sample = (counter == 0);			// while encoding is still underway.

	always @(posedge clk) begin
		if(reset) begin
			{data_in_latched, output_valid, busy} <= 0;
			counter <= `V-1;
		end
		else if(en) begin
			if(kick_off) begin
				data_in_latched <= data_in;
				counter <= `V-1;
				busy <= 1;
			end
			else if(busy) begin
				if(last_input_sample)
					busy <= 1'b0;

				counter <= counter - 1;
			end

			output_valid <= last_input_sample;
		end
	end

	// Main part. LFSR handle
	always @(posedge clk) begin
		if(reset)
			LFSR <= 0;
		else if(en) begin
			if(kick_off)
				LFSR <= 0;
			else if(busy) begin
				if(LFSR[`N-`K-1] ^ data_in_latched[counter])
					LFSR <= generator[`N-`K-1:0] ^ {LFSR[`N-`K-2:0], 1'b0};
				else
					LFSR <= {LFSR[`N-`K-2:0], 1'b0};
			end
		end
	end

	assign codeword_out = {data_in_latched, LFSR};
endmodule

module parallel_bch_encoder(
	input  wire [`V-1:0] data_in,
	output wire [`W-1:0] codeword_out,
	output wire busy,
	output wire output_valid,
	input  wire kick_off,
	input  wire en, clk, reset
);
	integer i;
	parameter PIPELINE_DEPTH = 2;

	wire [`N-`K-0:0] generator = 9'b111010001;
	reg  [`N-`K-1:0] LFSR;		// generator has 0 to N-K bits
	wire [`V-1 :0] data_in_latched = data_in;

	// Serialized LFSR handle
	always @(*) begin
		LFSR = 0;

		for(i=`V-1; i>=0; i-=1) begin
			if(LFSR[`N-`K-1] ^ data_in_latched[i])
				LFSR = generator[`N-`K-1:0] ^ {LFSR[`N-`K-2:0], 1'b0};
			else
				LFSR = {LFSR[`N-`K-2:0], 1'b0};
		end
	end

	// Pipelining
	reg [`N-`K-1:0] pLFSR_PL [0:PIPELINE_DEPTH];
	reg valid_PL [0:PIPELINE_DEPTH];

	always @(*) pLFSR_PL[0] = LFSR;
	always @(*) valid_PL[0] = kick_off;

	always @(posedge clk) begin
		for(i=1; i<=PIPELINE_DEPTH; i+=1) begin
			if(reset)
				{valid_PL[i], pLFSR_PL[i]} <= 'b0;
			else if(en) begin
				valid_PL[i] <= valid_PL[i-1];
				pLFSR_PL[i] <= pLFSR_PL[i-1];
			end
		end
	end

	assign busy = valid_PL[PIPELINE_DEPTH-1];
	assign output_valid = valid_PL[PIPELINE_DEPTH];

	assign codeword_out = {data_in_latched, pLFSR_PL[PIPELINE_DEPTH]};
endmodule

module testbench;
	reg  [`V-1:0] data_in;
	wire [`W-1:0] codeword_out_serial, codeword_out_parallel;
	wire output_valid_serial, output_valid_parallel;
	reg  kick_off;
	reg  en, clk, reset;


	serial_bch_encoder serial_bch_encoder_inst(
		.data_in(data_in),
		.codeword_out(codeword_out_serial),
		.output_valid(output_valid_serial),
		.kick_off(kick_off),
		.en(en), .clk(clk),
		.reset(reset)
	);

	parallel_bch_encoder parallel_bch_encoder_inst(
		.data_in(data_in),
		.codeword_out(codeword_out_parallel),
		.output_valid(output_valid_parallel),
		.kick_off(kick_off),
		.en(en), .clk(clk),
		.reset(reset)
	);

	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, testbench);

		#0 en = 0; clk = 0; reset = 0; kick_off = 0; data_in = 0;
		#1 reset = 1;
		#1 clk = 1;
		#1 clk = 0;
		#1 reset = 0;
		
		#1 en = 1;
		#1 data_in = 7'b1000000;
		#1 kick_off = 1;

		#1 clk = 1;
		#1 clk = 0;

		#1 kick_off = 0;

		repeat(20)
			#1 clk = ~clk;
	end
endmodule