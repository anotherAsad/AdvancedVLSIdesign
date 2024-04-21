function [idx, error_count, corrected_codeword] = BCH_decoder(input_codeword)
	idx = 15;
	a = gf([1:15], 4, 19);
	alpha = a(1+1);
	
	syndrome_1 = eval_poly(input_codeword, alpha.^1);
	syndrome_3 = eval_poly(input_codeword, alpha.^3);

	single_bit_error_flag = syndrome_1.^3 + syndrome_3;

	% determine error count
	error_count = 0;

	if syndrome_1 == 0 && syndrome_3 == 0
		error_count = 0;
	elseif (single_bit_error_flag == 0)
		error_count = 1;
	elseif (single_bit_error_flag ~= 0)
		error_count = 2; 
	end

	% correct errors
	correction_pattern = zeros(1, length(input_codeword)); 

	if(error_count == 1)
		correction_pattern(log(syndrome_1) + 1) = 1;
	elseif(error_count == 2)
		% RELP check -> syndrome_1 * x^2 + syndrome_1^2 * x == single_bit_error_flag
		term1 = syndrome_1;
		term2 = syndrome_1.^2;
		
		idx = 0;

		% chien search loop
		for i = 1:15
			relp = term1 + term2 + single_bit_error_flag;

			if relp == 0
				break;
			end

			term1 = term1 * alpha^2;
			term2 = term2 * alpha^1;

			idx = i;
		end

		correction_pattern(idx +1) = 1;
		% for second bit: S1 = bit1 xor bit2 -> bit2 = S1 xor alpha.^idx
		bit2 = syndrome_1 + alpha.^idx;
		correction_pattern(log(bit2)+1) = 1;
	end
	
	corrected_codeword = mod(input_codeword + correction_pattern, 2);
end