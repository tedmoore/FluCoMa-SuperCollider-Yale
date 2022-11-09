// =============== Non-negative Matrix Factorization ===============

// let's decompose the drum loop that comes with the FluCoMa extension:
~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// hear the original mono sound file to know what we're working with
~drums.play;

FluidWaveform(~drums);

// an empty buffer for the decomposed components to be written into:
~resynth = Buffer(s);

// how many components we want FluidBufNMF to try to decompose the buffer into:
~n_components = 3;

// process it:
FluidBufNMF.processBlocking(s,~drums,resynth:~resynth,components:~n_components,resynthMode:1,action:{"done".postln;});

// once it is done, play the separated components one by one
(
~synth = {
	arg which_comp = 0;
	var sig = PlayBuf.ar(~n_components,~resynth,BufRateScale.ir(~resynth),loop:1);
	sig = SelectX.ar(which_comp.lag(0.03),sig).dup;
}.play;
)

~synth.set(\which_comp,0);
~synth.set(\which_comp,1);
~synth.set(\which_comp,2);

// ====== bases and activations ========

(
~bases = Buffer(s);
~activations = Buffer(s);
)

// and we'll explicitly pass these into the process
FluidBufNMF.processBlocking(s,~drums,bases:~bases,activations:~activations,resynth:~resynth,resynthMode:1,components:~n_components,action:{"done".postln;});

// see activations
FluidWaveform(~drums,featuresBuffer:~activations,bounds:Rect(0,0,1200,300),stackFeatures:true);

// see buffers
FluidWaveform(featuresBuffer:~bases,bounds:Rect(0,0,1200,300),stackFeatures:true);

// ======== FluidNMFFilter ==========

(
~synth = {
	arg which_comp = 0;
	var src = PlayBuf.ar(1,~drums,BufRateScale.ir(~drums),loop:1);
	var sig = FluidNMFFilter.ar(src,~bases,~n_components);
	sig = SelectX.ar(which_comp.lag(0.03),sig).dup;
}.play;
)

~synth.set(\which_comp,0);
~synth.set(\which_comp,1);
~synth.set(\which_comp,2);

// if we play a different source through FluidNMFFilter, it will try to decompose that realtime signal according to the bases
// it is given (in our case the bases from the drum loop)
~song = Buffer.readChannel(s,FluidFilesPath("Tremblay-BeatRemember.wav"),channels:[0]);

(
~synth = {
	arg which_comp = 0;
	var src = PlayBuf.ar(1,~song,BufRateScale.ir(~song),loop:1);
	var sig = FluidNMFFilter.ar(src,~bases,~n_components);
	sig = SelectX.ar(which_comp.lag(0.03),sig).dup;
}.play;
)

~synth.set(\which_comp,0);
~synth.set(\which_comp,1);
~synth.set(\which_comp,2);

// ========= the activations could also be used as an envelope through time ===========
(
{
	arg which_comp = 0;
	var activation = PlayBuf.ar(3,~activations,BufRateScale.ir(~activations),loop:1);
	var sig = PinkNoise.ar(0.dbamp) * activation;
	sig = SelectX.ar(which_comp.lag(0.03),sig).dup;
}.play;
)

~synth.set(\which_comp,0);
~synth.set(\which_comp,1);
~synth.set(\which_comp,2);

// note that the samplerate of the ~activations buffer is not a usual one...
~activations.sampleRate;

// ====== NMFFilter & Playing Activations ============
(
{
	var activation = PlayBuf.ar(3,~activations,BufRateScale.ir(~activations),loop:1);
	var sig = WhiteNoise.ar(0.dbamp);
	sig = FluidNMFFilter.ar(sig,~bases,~n_components) * activation;
	Splay.ar(sig);
}.play;
)