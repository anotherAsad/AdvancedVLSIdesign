`define M 8
`define N (2**`M-1)			// 255
`define K 239					// message size
`define dropped_MSB 111

function [3:0] field_modulo(input [7:0] inp);
	if(inp >= 2*`N)
		field_modulo = inp - 2*`N;
	else if(inp >= `N)
		field_modulo = inp - 1*`N;
	else
		field_modulo = inp;
endfunction

module alpha;
	reg [`M-1:0] power [0:2**`M-1];
	reg [`M-1:0] log   [0:2**`M-1];

	// generated from matlab
	initial begin
		power['h0] = 'h1;	log['h0] = 'hf;					// for log, this denotes an error
		power['h1] = 'h2;	log['h1] = 'h0;
		power['h2] = 'h4;	log['h2] = 'h1;
		power['h3] = 'h8;	log['h3] = 'h4;
		power['h4] = 'h3;	log['h4] = 'h2;
		power['h5] = 'h6;	log['h5] = 'h8;
		power['h6] = 'hc;	log['h6] = 'h5;
		power['h7] = 'hb;	log['h7] = 'ha;
		power['h8] = 'h5;	log['h8] = 'h3;
		power['h9] = 'ha;	log['h9] = 'he;
		power['ha] = 'h7;	log['ha] = 'h9;
		power['hb] = 'he;	log['hb] = 'h7;
		power['hc] = 'hf;	log['hc] = 'h6;
		power['hd] = 'hd;	log['hd] = 'hd;
		power['he] = 'h9;	log['he] = 'hb;
		power['hf] = 'h1;	log['hf] = 'hc;
	end
endmodule