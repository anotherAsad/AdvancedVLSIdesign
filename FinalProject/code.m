% DEC-TED BCH(15, 7, 5)
systematic = false;

a = gf([1:15], 4, 19);
alpha = a(1+1);

generator = [1 0 0 0 1 0 1 1 1];			% 1 + x^4 + x^6 + x^7 + x^8
msg = [0 0 0 0 0 0 1];						% x^6

if systematic
	coded = [0 0 0 1 0 1 1 1, msg];
else
	coded = gfconv(generator, msg);
end

error_pattern = zeros(1, length(coded));
error_pattern(15) = 0;
error_pattern(12) = 1;
error_pattern(02) = 1;

rxsig = mod(coded + error_pattern, 2);


[idx, err_count, corrected_codeword] = BCH_decoder(rxsig);

% disp([syndrome_0, syndrome_1, syndrome_3, syndrome_1.^3 == syndrome_3]);

fprintf('error_count: %d\n', err_count);
disp([coded; corrected_codeword]);
