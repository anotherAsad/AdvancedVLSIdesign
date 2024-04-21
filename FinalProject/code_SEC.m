a = gf([1:15], 4, 19);
t = 3;

alpha = a(1+1);

generator = [1 1 0 0 1];			% 1 + x + x^4
msg = [0 0 0 0 0 0 0 0 0 0 1];		% x^10

coded = gfconv(generator, msg);

error_pattern = zeros(1, length(coded));
error_pattern(11) = 1;
rxsig = mod(coded + error_pattern, 2);

syndrome = eval_poly(rxsig, alpha.^1);
Lambda_1 = syndrome;
error_position_coeff = 1/Lambda_1;

disp(log(1/error_position_coeff));			% equivalent to disp(log(syndrome))