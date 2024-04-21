function res = eval_poly(poly, root)
	idx = find(poly);
	
	res = 0;
	
	for x = idx
		res = res + root.^(x-1);
	end
end