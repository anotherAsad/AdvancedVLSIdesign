%lpf_A = designfilt('lowpassfir', 'PassbandFrequency', .2, 'StopbandFrequency', 0.23, 'PassbandRipple', 0.1, 'StopbandAttenuation', 60, 'DesignMethod', 'equiripple');
lpf_equi = designfilt('lowpassfir', 'PassbandFrequency', .2, 'StopbandFrequency', 0.23, 'PassbandRipple', 0.308, 'StopbandAttenuation', 80, 'DesignMethod', 'equiripple');

fvtool(lpf_equi);

coeff = lpf_equi.Coefficients;

% hold on;
% freqz(coeff)
% freqz(round(coeff*2^13)./2^13)

[h{1},w{1}] = freqz(coeff);
[h{2},w{2}] = freqz(round(coeff*2^15)./2^15);
figure
subplot(2,1,1)
hold on
for k = 1:2
    plot(w{k},20*log10(abs(h{k})))
end
hold off
grid
subplot(2,1,2)
hold on
for k = 1:2
    plot(w{k},unwrap(angle(h{k})))
end
hold off
grid


% file printing
fixed_point_coeffs = round(coeff*2^15).';
fixed_point_coeffs(fixed_point_coeffs < 0) = 2.^16 + fixed_point_coeffs(fixed_point_coeffs < 0);

fileID = fopen("coefficients.txt", "w");

for i = 0:length(fixed_point_coeffs)-1
	fprintf(fileID, "fir_coeff[%d] = 16'h%X;\n", i, fixed_point_coeffs(i+1));
end

fclose(fileID);