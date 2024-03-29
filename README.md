# Advanced VLSI Design - Term Project
This is the report on the FIR design project. It showcases:
- The MATLAB filter design process.
- Coefficient exporting for HDL description.
- Various HDL implementations of the FIR.
- Usage of Synopsys Design Compiler.
- Timing, Area and Power reports from Synopsys Design Compiler.

**Note**: The main testbench is in the `code.v` file. Use `run_sns.ps1` script to simulate the design.

<h2>MATLAB Section</h2>

_keywords:_ `FIR filter design`, `Q-formats`, `quantization noise`

MATLAB's `designfilt` tool was used to design a filter with required properties, i.e., with a transition region of **0.2 $\pi$ to 0.23 $\pi$ rad/sample**, and a **stop-band attenuation of 80 dB**.

<h3>Filter Details</h3>

The filter was generated using the equiripple design method. The command used to generate the filter is as follows:

```MATALAB
lpf_equi = designfilt('lowpassfir', 'PassbandFrequency', .2, 'StopbandFrequency', 0.23, 'PassbandRipple', 0.308, 'StopbandAttenuation', 80, 'DesignMethod', 'equiripple');
```

For the given constraints, a decent equiripple design takes more than 100 taps. For low passband ripple, and for ease of decomposition during L2 and L3 parallel filter design, I have chosen to implement a filter with **204 taps**.

The filter impulse response, extracted using `fvtool` utility in MATLAB, is given below:

![graph](./Pictures/MATLAB/fvtool.PNG)

As can be seen, the response is that of an equiripple low-pass filter, with stop-band attenuation of the 80 dB, and requisite transition region width of 0.03 $\pi$ rad/sample.

<h3>Filter Quantization</h3>

The absolute maximum value for filter coefficients (the top of the $sinc$ function, i.e. the value in the middle) was **0.2069**. Considering this, a fixed-point representation format of signed $Q1.15$ was chosen. This means that the coefficients will be stored in 16-bit numbers. 1 bit will be used to represent the sign, and 15 bits will be used to represent the fractional part.

The post quantization frequency response is given in the following figure:

![graph](./Pictures/MATLAB/freqz.PNG)

The top figure shows the magnitude response, while the bottom figure shows the phase response. The *blue* traces represent the original/un-quantized filter response, whereas the *orange* trace shows the post quantization response. As can be seen, quantization impacts the stop-band: the response is no longer perfectly equiripple, and the stop-band attenuation is no more below the stipulated 80 dB - it now goes only as low as around 74 dB.

<h4></h4>

The MATLAB script in the file `code.m` was used to generate the filter, quantize it, display the filter impulse response, and dump the filter coefficients for verilog consumption.

<h2>FIR implementations in Verilog HDL</h2>

One could think of many ways to implement FIR filters in hardware. I have implemented the given low-pass FIR filter in the following flavors:

1. **Direct Form**: *The naive design. Uses a massive adder to sum up all delayed multiplication products. This massive adder adds 204 products combinationally. Results in an atrociously long critical path*.
2. **Pipelined Direct Form**: _The adder from the above design is pipelined: It is broken down logarithmically, with every further stage requiring half or so number of adders than the last one._
3. **Broadcast Form**: _The FIR filter is expressed in a form which is naturally pipelined, and uses a low resource count. The input samples are **broadcast** to all the multipliers at once._
4. **Broadcast Form with Fine Grain Pipelining**: _The multipliers in broadcast form are finegrain-pipelined._
5. **Symmetric Broadcast Form**: _Since the coefficients of a low-pass filter are symmetric around the y-axis, half the multiplications in broadcast form are redundant. We can exploit this symmetry and reduce the multiplier count by half, since any two multipliers at an equal distance from the middle will have the same output._
6. **L2 Parallel**: _Reduced complexity L2 parallel implementation._
7. **L2 Parallel**: _Reduced complexity L3 parallel implementation._

Given below are the design block diagrams of different FIR implementations. Each implementation has a corresponding verilog file with the same or similar name:

<h3>1. Direct Form</h3>

This is the most naive form, derived from the convolution expression of an FIR. As can be seen in the figure, this implementation needs a huge adder, which combinationally adds the outputs of all the multipliers. This results in a horribly long critical path.

![graph](./Pictures/Drawings/DirectForm_Original.png)

<h3>2. Pipelined Direct Form</h3>

This implementation breaks down the slow adder from the above implementation to a log-pipelined adder. Every stage adds only two operands, and passes on the result to the next stage. This results in a total adder count of `FILTER_SIZE-1`. These pipelined stages help reduce the critical path.

A useful tip is to limit the log-pipelining stages to such an extent that the adder critical path is broken down into a path that is _just_ shorter than the second worst critical path. Any further pipelining will not help in critical path propagation delay reduction, but still consume area/cell resources.

Through experimentation, I found that 6 combinational adders at the final stage do not form the critical path. This is reflected in the verilog code.

![graph](./Pictures/Drawings/DirectForm_pipelined.png)

<h3>3. Broadcast Form</h3>

The broadcast representation of an FIR filter is inherently pipelined. It also uses less delay elements in comparison to pipelined direct form. The block diagram is given below:

![graph](./Pictures/Drawings/broadcast_fir_noFG.png)

<h3>4. Broadcast Form with Fine-grained Pipelining</h3>

Supports additional, 1 stage fine-grained pipelining between adders and multipliers.

![graph](./Pictures/Drawings/broadcast_fir.png)

<h3>5. Symmetric Broadcast Form</h3>

An equiripple low-pass FIR filter is symmetric around the y-axis, i.e., `h[n] == h[FILTER_SIZE-n-1]`. This means that the results of multiplications are also symmetric around the center of the broadcast FIR. We can use this symmetry to eliminate half of the redundant FIRs.

The block diagram of a modified broadcast FIR is shown below:

![graph](./Pictures/Drawings/broadcast_fir_symmetric.png)

The symmetry exploitation only works for non-parallel implementations, because in parallel implementations, the coefficients of subfilters (decomposed filters H0, H1, H2 etc.) are not symmetric.

<h3>6. L2 Parallel Form</h3>

The L2 parallel form is the reduced-complexity parallel implementation of the given filter. It employs filter decomposition and clever recombination to achieve a parallel implementation capable of _2x_ throughput of the broadcast form, while using around _1.5x_ filter hardware resources.

One feature of note: The L2 parallel design uses two clocks; one for processing, and one for serialization/de-serialization of inputs and outputs. The ser-des clock has twice the frequency to keep the filter fed at all times.

Below is the block-diagram I used as a reference to implement the L2 parallel design:

![graph](./Pictures/Drawings/L2.PNG)

<h3>7. L3 Parallel Form</h3>

The L3 frequency works essentially on the same principle as L3. It can give _3x_ throughput while using _2x_ filter resources (The L3 implementation has 6 filters, with each having a length of 1/3 of the original).

The L3 system is also fed using a _3x_ faster clock that is used for serialization and de-serialization of the incoming/outgoing data. The internal core works in parallel at a slower clock.

Below is the block-diagram I used as a reference to implement the L2 parallel design:

![graph](./Pictures/Drawings/L3.PNG)

Since both L2 and L3 parallel designs use **broadcast FIR filters** as their basic building blocks, one must make sure that the filter coefficients are passed on in the inverted order (i.e. `h[0]` goes to the last multiplier, and `h[N-1]` goes to the first multiplier). Otherwise, filter recombination is incorrect and will produce wrong results.

$Note:$ The L2 and L3 parallel implementations use the **pipelined, broadcast FIR implementations** for their internal subfilters.

<h3>Avoiding Overflows in Filter Design</h3>

The following points explain my rationale in choosing output bit-widths to avoid overflows:

- As stated in the MATLAB section, the filter coefficients are stored in signed $Q1.15$ fixed-point format, and need 16-bits each.
- Given that every input `x[n]` is also constrained between $-0.999$ and $+0.999$, we can use the same signed $Q1.15$ format to represent inputs.
- This means that every multiplication (product of 2 signed 16-bit numbers in $Q1.15$ format) will occupy 32-bit, and have a $Q2.30$ as format. Both of the two non-fractional bits represent sign bit. So we have 31 bits of information at the output of each multiplier.
- Since we have a $204$ tap filter, we need to perform $204$ additions on the multiplication outputs.
- Every 2-operand addition has the potential to add 1 more bit to the output, given that both operands are max representable values in the given fixed-point format.
- Since we can breakdown the $204$ additions into a log-tree with 8 steps, we need 8 more fractional bits to avoid overflow. This is corroborated by the fact that since our max multiplication output is $~0.9999$, 204 such additions will result in something around $203.999$, which needs 8 non-fractional bits.
- So to avoid overflow, the final adder output must have at least 8 non-fractional bits.
- In the interest of saving resources, we can drop the lower, fractional bits of multipliers, and translate the q-format from $Q2.30$ to $Q1.15$ at a moderate precision loss.
- Then, the required final Q-format at the adder outputs is $Q9.15$, and needs 24-bits.


<h2>Testbench Simulation Results</h2>

For simulation of the FIR implementations, I have used **iverilog**, in conjunction with **GTKwave**. The testbench used for simulations instantiates all pertinent FIR implementations, and passes the same input data to them. The outputs can thus be compared side-by-side.

The simulation testbench uses three clocks:

1. `clk` is used as the main processing clock for all FIR implementations.
2. `clk_2x` is used to serialize/deserialize data for **L2 parallel** implementation.
3. `clk_3x` is used to serialize/deserialize data for **L3 parallel** implementation.

All three clocks are in phase.

<h3>Post Simulation Waveform</h3>

The following figure shows the post-simulation waveform:
![graph](./Pictures/GTKwave/Comprehensive.PNG)

This waveform shows the response of all the different FIR implementations when a single sample, impulse input is passed on to it. Description of the above waveform is as follows:

1. Just after the marker, a single sample of input, representing **~+1** in $Q1.15$ is passed.
2. In the violet _baseline_ traces, we can see the output of different non-parallel implementations of the FIR (e.g. direct form, log_pipelined direct_form, broadcast, broadcast symmetric etc). You can see that all the output samples have the same order for all the FIR implementations. They agree with each other, and also agree with the matlab filter coefficients. The **log-pipelined direct form implementation** lags quite a bit. This is due to the extra steps needed for addition in the implementation.
3. The next trace is the _re-serialized_ output of the **L2 parallel** implementation. It is in orange, and has double the data rate as compared to non parallel implementations.
4. In blue, we have the  _re-serialized_ output of the **L3 parallel** implementation.The data rate is 3x, and every output sample arrives at the rising edge of the `clk_3x` ser-des clock.
5. In `Parallel_L2` section, we have the serialized output in blue; and the original, parallel output in orange. As can be seen, the parallel output is at the lower clock rate. Also, read from _top to bottom_, `data_out_0` and `data_out_1` form the reserialized output shown just above.
6. In the `Parallel_L3` section, again, the serialized output is in blue. The 3-parallel output is in orange. From top to bottom, the outputs correspond to $y(3k)$, $y(3k+1)$ and $y(3k+2)$. Again the post serialization output agrees with the parallel output, and the output of other FIRs.


<h3>Analog Waveform</h3>

To show the veracity of implementations, the analog representation of the filter responses is given below. The input sample is a digital impulse. The outputs of 3 FIRs (broadcast non-parallel, L2 parallel and L3 parallel) are shown in violet, orange and green.

![graph](./Pictures/GTKwave/Analog.PNG)

As can be seen, all outputs are $sinc$ functions, which correspond to $rect$s in the frequency domain, i.e. **Low-pass filters**. The outputs of parallel filters are _squished_ by a factor of 2 and 3 respectively, because they are re-serialized at higher clocks.

<h2>Synthesis using Synopsys Design Compiler</h2>

The Synopsys Design  Compiler is invoked by entering `design_vision` in the terminal. At the beginning of a new project, one must expose the cell libraries that are to be used for synthesis and compilation. A setup script written to achieve that looks like the one given below:

```bash
# Define the target logic library, symbol library,
# and link libraries
set_app_var target_library lsi_10k.db
set_app_var symbol_library lsi_10k.sdb
set_app_var synthetic_library dw_foundation.sldb
set_app_var link_library "* $target_library $synthetic_library"
set_app_var search_path [concat $search_path ./src]
set_app_var designer "Asad"
# Define aliases
alias h history
alias rc "report_constraint -all_violators"
```

This script sets up `lsi_10k` library as a source for cells and technology specific constraints. In actual synthesis, I have used `FreePDK-45`, which is a free, **45 nm** library available all over the internet.

<h3>Steps for Design Compilation</h3>

I have been using the following steps to compile my FIR implementations:

1. Setup cell library (as stated above).
2. Analyze the verilog module to be synthesized. Use `File -> Analyze`. It turns out that the design compiler supports a very strict subset of verilog. One may have to re-tailor the code at some spots to make it pass with a design compiler.
3. Elaborate the top module. Use `File -> Elaborate`.
4. Specify timing and load capacitance constraints. I have batched my specifications in a `tcl` script given below:
   ```tcl
   link
   uniquify
   # specify clk
   create_clock clk -period 42 -waveform {0 20}
   set_clock_latency 0.3 clk
   set_input_delay 2.0 -clock clk [all_inputs]
   set_output_delay 1.65 -clock clk [all_outputs]
   # specify clk_serial
   create_clock clk_serial -period 14 -waveform {0 7}
   set_clock_latency 0.3 clk_serial
   set_input_delay 2.0 -clock clk_serial [all_inputs]
   set_output_delay 1.65 -clock clk_serial [all_outputs]
   # specify loads
   set_load 0.1 [all_outputs]
   set_max_fanout 1 [all_inputs]
   set_fanout_load 8 [all_outputs]
   report_port
   ```
5. Check Design. Use `Design -> Check Design`.
6. Compile Design. USe `Design -> Compile Design`.

<h3>Steps for Report Generation</h3>

From here on, one can generate **timing, area and power** reports. The steps to do that are as follows:

1. Use `Timing -> Report Timing Path` to generate timing reports. The crucial metric here is the **slack**. Defined in units of nano-seconds, it is the spare time budget of the critical path for a specified clock period. For example, let's assume a specified clock period of 100 ns, and a critical path of 98 ns. Here, the slack will be calculated as: `specified clock period - critical path propagation delay = +2 ns`. This means that we can still decrease the clock period by 2 ns, and the design will keep working. On the other hand, a negative slack means that the timing constraints have failed. As an example, a slack of -2 ns means that we have to slow the clock down by 2ns to meet timing requirements.
2. Use `Design -> Report Area` to generate an area report. Area is reported in terms of cells used.
3. Use `Design -> Report Power` to generate power estimation reports.

<h2>Post-synthesis Timing and Resource/Power Usage Reports</h2>

Screenshots of post-synthesis/post-compilation reports for different designs can be found in the directory `Pictures/SynopsysDesignCompiler`. In the interest of brevity, I will show the **screenshots** of only one designs here. For the rest, I will summarize the results in a table at the end of this section.

<h3>Screenshots Broadcast form FIR reports</h3>

<h4>Timing Report:</h4>

![graph](./Pictures/SynopsysDesignCompiler/Broadcast/TimingReport.PNG)

The critical path (highlighted) is due to a multiplier, and has a propogation delay of $5.77 ns$. The target clock period is $40 ns$, corresponding to $25 MHz$ frequency. The slack is $34.47 ns$. Which means that this design can run at the max clock frequency of about $173 MHz$.

<h4>Area Report:</h4>

![graph](./Pictures/SynopsysDesignCompiler/Broadcast/AreaReport.PNG)

Total cell area is 142251 units. Net area in mm^2 is undefined, because I haven't specified pin-out details like wireloads etc.

<h4>Power Report:</h4>

![graph](./Pictures/SynopsysDesignCompiler/Broadcast/PowerReport.PNG)

Estimated power consumption is around $4 mW$. Of which, around $3.274 mW$ are accounted for as dynamic power consumption.

<h3>Comparison Table for Different Implementations</h3>

This section concisely compares all the FIR implementations on various metrics.

Given below is a table that compares the timing, power and area reports for all our designs:

![graph](./Pictures/SynopsysDesignCompiler/ReportTable.PNG)

The results seem more or less expected. A detailed analysis on the results of this table are given in the next section.

<h2>Conclusion</h2>

From the table above, one can draw the following conclusions:

<h3>Timing Analysis</h3>

1. In terms of timing, the **Direct Form** implementation is the worst design. The slack is zero, which means that despite all the optimizations, the design _just_ meets the timing constraints.
2. The **log-pipelined** direct form design is the best in terms of timing. It has a lot of time budget, i.e. a slack of $36.25 ns$. This is also expected, since it has a lot of hand-tuned optimizations. Moreover, the design is uniquely amicable to compile-time re-timing. The design compiler must have fine-grained pipelined the multipliers from the extra budget of log-pipelined adders.
3. The broadcast designs, due to their natural pipelining, exhibit high max operating frequencies. The additional fine-grained pipelining also helps in improving max operating frequency, but this comes at the cost of around $1.6x$ more area consumption.
4. The symmetry exploiting design has a similar timing performance to the broadcast design. This means that the bottleneck is not the redundant multipliers.
5. Both **L1** and **L2** parallel designs have similar max operating frequency, but have 2x and 3x datarate respectively. Both of them are based off of finegrain pipelined broadcast design.

<h3>Power Analysis</h3>

1. All designs consume around 80% of the net power as dynamic power.
2. It seems like registers consume a lot of power, since designs with lower register count have lower power consumption (Compare pipelined and non-pipelined broadcast design).
3. Due to symmetry exploitation, there is a **significant reduction in net power consumption**. This means that the redundant multipliers, although not impacting the critical path, were using up a lot of power.
4. Due to large resource count, the $L2$ and $L3$ parallel designs seem power hungry. But I can't understand why their power consumption is so much higher than the base design.

<h3>Area Analysis</h3>

1. The direct form, with its enormous combinational adder, has the largest real estate consumption.
2. After symmetry exploitation, the area reduces by around $20\%$ due to lesses multiplier count.
3. Most interestingly, the **parallel L2** design has $1.6x$ more area than the baseline design. This agrees remarkably well with the first-principle extimation of $1.5x$, because L2 design is supposed to use 3 filters of 1/2 of the original length, i.e., $1.5x$ the original filter complexity.
4. Similarly, the **parallel L3** design uses $2.2x$ more area than the base line design. The first-principle estimation was $2x$, because we have 6 sub-filters, each with 1/3 of the original length.


