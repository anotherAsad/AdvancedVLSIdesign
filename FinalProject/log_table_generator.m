M = 4;

a = gf([1:2.^M-1], M, 19);

alpha = a(1+1);

for i=0:15
	k = alpha.^i;
	
	if i == 0
		log_val = 15;
	else
		log_val = log(a(i));
	end
	
	fprintf("power[\'h%x] = 'h%x;\tlog[\'h%x] = 'h%x;\n", i, k.x, i, log_val);
end