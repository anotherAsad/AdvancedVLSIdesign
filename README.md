# AdvancedVLSIdesign
Contains project submissions for Advanced VLSI Design course - Spring 2024

<h2>MATLAB Section</h2>

Keywords: `FIR filter design`, `Q-formats`, `quantization noise`

MATLAB's `designfilt` tool was used to design a filter with required properties, i.e., with a transition region of **0.2$\pi$ to 0.23$\pi$ rad/sample**, and a **stop-band attenuation of 80 dB**.

<h3>Filter Details</h3>

The filter was generated using the equiripple design method. The command used to generate the filter is as follows:

```MATALAB
lpf_equi = designfilt('lowpassfir', 'PassbandFrequency', .2, 'StopbandFrequency', 0.23, 'PassbandRipple', 0.308, 'StopbandAttenuation', 80, 'DesignMethod', 'equiripple');
```

For the given constraints, a decent equiripple design takes more than 100 taps. For low passband ripple, and for ease of decomposition during L2 and L3 parallel filter design, I have chosen to implement a filter with **204 taps**.

The filter impulse response, extracted using `fvtool` utility in MATLAB, is given below:

![graph](./Pictures/MATLAB/fvtool.png)

As can be seen, the response is that of an equiripple low-pass filter, with stop-band attenuation of the 80 dB, and requisite transition region width of 0.03 $\pi$ rad/sample.

<h3>Filter Quantization</h3>

The absolute maximum value for filter coefficients (the top of the sinc function, i.e. the value in the middle) was **0.2069**. Considering this, a fixed-point representation format of signed Q1.15 was chosen. This means that the coefficients will be stored in 16-bit numbers. 1 bit will be used to represent the sign, and 15 bits will be used to represent the fractional part.

The post quantization frequency response is given in the following figure:

![graph](./Pictures/MATLAB/freqz.PNG)


<h4></h4>
The MATLAB script in the file `code.m` was used to generate the filter, quantize it, display the filter impulse response, and dump the filter coefficients for verilog consumption.
