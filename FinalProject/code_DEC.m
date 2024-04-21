% DEC-TED BCH(15, 7, 5)
systematic = true;

a = gf([1:15], 4, 19);
t = 3;

alpha = a(1+1);

generator = [1 0 0 0 1 0 1 1 1];			% 1 + x^4 + x^6 + x^7 + x^8
msg = [0 0 0 0 0 0 1];						% x^6

if systematic
	coded = [0 0 0 1 0 1 1 1, msg];
else
	coded = gfconv(generator, msg);
end

error_pattern = zeros(1, length(coded));
error_pattern(15) = 1;
error_pattern(14) = 1;
error_pattern(13) = 1;

rxsig = mod(coded + error_pattern, 2);

syndrome_0 = eval_poly(rxsig, alpha.^0);
syndrome_1 = eval_poly(rxsig, alpha.^1);
syndrome_3 = eval_poly(rxsig, alpha.^3);

single_bit_error_flag = syndrome_1.^3 + syndrome_3;

% determine error count
error_count = 0;

if syndrome_1 == 0 && syndrome_3 == 0 && syndrome_0.x == mod(sum(coded), 2)
	error_count = 0;
elseif (single_bit_error_flag == 0)  && syndrome_0.x ~= mod(sum(coded), 2)
	error_count = 1;
elseif (single_bit_error_flag ~= 0)  && syndrome_0.x == mod(sum(coded), 2)
	error_count = 2;
else
	error_count = 3;
end

% correct errors
correction_pattern = zeros(1, length(coded)); 

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


% disp([syndrome_0, syndrome_1, syndrome_3, syndrome_1.^3 == syndrome_3]);

fprintf('error_count: %d\n', error_count);
disp([error_pattern; correction_pattern]);
