`default_nettype none

`include "tables.sv"

`define W `N-`dropped_MSB		// length of the coded message.	
`define V `K-`dropped_MSB		// length of the input message


module serial_syndrome_calculator(
	output reg  data_out_valid,
	output wire error_found,
	output reg  busy,
	output reg  [`M-1:0] S_1, S_3,
	input  wire [`W-1:0] rx_data,
	input  wire kick_off,
	input  wire en, clk, reset
);
	integer i;

	reg [`M+1:0] counter;
	reg [`W-1:0] rx_data_latch;

	wire last_input_sample = (counter == `W-1);		// 0 .. 14 

	// Sequential syndrome calculator
	always @(posedge clk) begin
		if(reset)
			{counter, busy, data_out_valid} <= 0;
		else if(en) begin
			if(kick_off) begin
				busy <= 1'b1;
				
				counter <= 'd0;
				rx_data_latch <= rx_data;
				S_1 <= 'd0;
				S_3 <= 'd0;
			end
			else if(busy) begin
				if(last_input_sample)
					busy <= 1'b0;
				// increment counter.
				counter <= counter + 1;
				// iteratively calculate syndrome
				S_1 = S_1 ^ (alpha.power[counter] & {4{rx_data_latch[i]}});						// extend
				S_3 = S_3 ^ (alpha.power[field_modulo(3*counter)] & {4{rx_data_latch[i]}});		// extend
			end

			// data_out_valid handle 
			data_out_valid <= last_input_sample;
		end
	end

	assign error_found = (S_1 != 4'd0) || (S_3 != 4'd0);
endmodule

module parallel_syndrome_calculator(
	output wire data_out_valid,
	output wire error_found,
	output wire [`M-1:0] S_1, S_3,
	input  wire [`W-1:0] rx_data,
	input  wire rx_data_valid,
	input  wire en, clk, reset
);
	integer i;
	parameter PIPELINE_DEPTH = 0;

	reg [`M-1:0] S_1_acc, S_3_acc;		// XOR sum accumulators.		

	// Combinational, unrolled syndrome calculator
	always @(*) begin
		S_1_acc = 4'd0;
		S_3_acc = 4'd0;

		for(i=0; i<`W; i+=1) begin			
			S_1_acc = S_1_acc ^ (alpha.power[i] & {4{rx_data[i]}});						// extend
			S_3_acc = S_3_acc ^ (alpha.power[field_modulo(3*i)] & {4{rx_data[i]}});		// extend
		end
	end

	// Pipelining
	reg [`M-1:0] S_1_PL [0:PIPELINE_DEPTH];
	reg [`M-1:0] S_3_PL [0:PIPELINE_DEPTH];

	reg valid_PL [0:PIPELINE_DEPTH];

	always @(*) S_1_PL[0] = S_1_acc;
	always @(*) S_3_PL[0] = S_3_acc;

	always @(*) valid_PL[0] = rx_data_valid;

	always @(posedge clk) begin
		for(i=1; i<=PIPELINE_DEPTH; i+=1) begin
			if(reset)
				valid_PL[i] <= 'b0;
			else if(en) begin
				valid_PL[i] <= valid_PL[i-1];

				S_1_PL[i] <= S_1_PL[i-1];
				S_3_PL[i] <= S_3_PL[i-1];
			end
		end
	end

	assign S_1 = S_1_PL[PIPELINE_DEPTH];
	assign S_3 = S_3_PL[PIPELINE_DEPTH];

	assign error_found = (S_1 != 4'd0) || (S_3 != 4'd0);
	assign data_out_valid = valid_PL[PIPELINE_DEPTH];
endmodule

// chien search embedded within.
module error_corrector(
	output reg  stall,
	output reg  output_valid,
	output wire invalid_correction_detected,							// No guarantees this will detect every invalid correction.
	output reg  [`M-1:0] single_bit_error_flag,
	output reg  [`W-1:0] correction_mask,
	input  wire [`M-1:0] S_1, S_3,
	input  wire input_valid, error_found,
	input  wire en, clk, reset
);
	wire [`M+1:0] log_S1 = alpha.log[S_1];							// extra bits to allow for 3x expansion
	wire [`M-1:0] S_1_cube = alpha.power[field_modulo(3*log_S1)];

	assign single_bit_error_flag = S_1_cube ^ S_3;

	wire [`M-1:0] single_error_loc = log_S1;
	reg  [`M-1:0] chien_loc_0, chien_loc_1;
	reg  chien_search_complete;

	// correction_mask handle
	// TO DO: Rework on this
	always @(*) begin
		if(input_valid & error_found & single_bit_error_flag == 0) begin
			correction_mask = (1'b1 << single_error_loc);
			output_valid = 1'b1;
		end
		else begin
			correction_mask = (1'b1 << chien_loc_0) | (1'b1 << chien_loc_1);
			output_valid = chien_search_complete;
		end
	end

	// *** *** *** *** *** *** *** *** *** *** CHIEN SEARCH SECTION *** *** *** *** *** *** *** *** *** *** //
	// chien search block
	reg  [`M-1:0] term1, term2;
	// reverse error locator polynomial
	wire [`M-1:0] relp = term1 ^ term2 ^ single_bit_error_flag;
	reg  [`M+1:0] counter;

	wire search_passed = stall && (relp == 0);
	wire search_failed = stall && (counter == `W); 			// means counter overflow at 15th sample
	
	wire search_complete = search_failed | search_passed;		// runs from 0 .. 15, or whenever the correction condition is met.

	// chien search block
	always @(posedge clk) begin
		if(reset)
			{term1, term2, stall, counter} <= 0;
		else if(en) begin
			if(input_valid && error_found && single_bit_error_flag != 4'd0) begin
				stall <= 1;
				term1 <= S_1;
				term2 <= alpha.power[field_modulo(2*log_S1)];
				counter <= 0;
			end
			else if(search_complete) begin		// If counter runs past the codeword length, or if the relp matches.
				stall <= 0;
			end
			else if(stall) begin
				counter <= counter + 1;

				term1 <= alpha.power[field_modulo(alpha.log[term1] + 2)];
				term2 <= alpha.power[field_modulo(alpha.log[term2] + 1)];
			end
		end
	end

	// chien_search output handle
	always @(posedge clk) begin
		if(reset)
			{chien_loc_0, chien_loc_1, chien_search_complete} <= 0;
		else if(en) begin
			chien_search_complete <= search_complete;

			// if search is complete, update outputs. Values of chien_locs exceeding `W will indicate failures, regardless of the cause: counter_overflow or pair out of vector. 
			if(search_complete) begin										
				chien_loc_0 <= counter;
				chien_loc_1 <= alpha.log[alpha.power[counter] ^ S_1];
			end
		end
	end

	// Indicate possible failures.
	assign invalid_correction_detected = chien_search_complete && (
											(chien_loc_0 >= `W) ||
											(chien_loc_1 >= `W)
										);
endmodule

// data must stay steady here.
module BCH_decoder(
	output wire decoder_busy,
	output wire decode_failure,
	output wire [`W-1:0] corrected_data,
	output wire output_valid,
	input  wire [`W-1:0] rx_data,
	input  wire rx_data_valid,
	// misc. signals
	input  wire en, clk, reset
);
	// syndrome calculator wires
	wire syncalc_output_valid;
	wire syncalc_error_found;
	wire [`M-1:0] S_1, S_3;

	parallel_syndrome_calculator syndrome_calculator(
		.data_out_valid(syncalc_output_valid),
		.error_found(syncalc_error_found),
		.S_1(S_1), .S_3(S_3),
		.rx_data(rx_data),
		.rx_data_valid(rx_data_valid),
		.en(en), .clk(clk), .reset(reset)
	);
	
	wire [`M-1:0] single_bit_error_flag;
	wire [`W-1:0] correction_mask;

	wire errcorr_output_valid;
	wire errcorr_busy, errcorr_invalid_correction;

	// chien search embedded within.
	error_corrector error_corrector_inst(
		.stall(errcorr_busy),
		.output_valid(errcorr_output_valid),
		.invalid_correction_detected(errcorr_invalid_correction),			// No guarantees this will detect every invalid correction.
		.single_bit_error_flag(single_bit_error_flag),
		.correction_mask(correction_mask),
		.S_1(S_1), .S_3(S_3),
		.input_valid(syncalc_output_valid),
		.error_found(syncalc_error_found),
		.en(en), .clk(clk), .reset(reset)
	);

	assign output_valid = errcorr_output_valid;
	assign decoder_busy = errcorr_busy;
	assign decode_failure = errcorr_invalid_correction;
	assign corrected_data = correction_mask ^ rx_data;
endmodule

module testbench;
	reg  [`W-1:0] rx_data;
	wire [`W-1:0] codeword_out_serial, codeword_out_parallel;
	wire output_valid_serial, output_valid_parallel;
	reg  kick_off;

	wire decode_failure, busy;

	reg  en, clk, reset;

	// data must stay steady here.
	BCH_decoder BCH_decoder_inst(
		.decoder_busy(busy),
		.decode_failure(decode_failure),
		.corrected_data(codeword_out_serial),
		.output_valid(output_valid_serial),
		.rx_data(rx_data),
		.rx_data_valid(kick_off),
		// misc. signals
		.en(en), .clk(clk),
		.reset(reset)
	);

	/*
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
	*/

	initial begin
		$dumpfile("test.vcd");
		$dumpvars(0, testbench);

		#0 en = 0; clk = 0; reset = 0;
		#1 reset = 1;
		#1 clk = 1;
		#1 clk = 0;
		#1 reset = 0;
		
		#1 en = 1;
		#1 rx_data = 15'b111010001000000 ^ ((1 << 11) | (1 << 1));
		#1 kick_off = 1;

		#1 clk = 1;
		#1 clk = 0;

		#1 kick_off = 0;

		repeat(40)
			#1 clk = ~clk;
	end
endmodule