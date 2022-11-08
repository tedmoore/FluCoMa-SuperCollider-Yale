// ============= Harmonic Percussive Source Separation =========================

//load buffers
(
~src = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
~harmonic = Buffer.new(s);
~percussive = Buffer.new(s);
)

// run with basic parameters
FluidBufHPSS.processBlocking(s,~src,harmonic:~harmonic,percussive:~percussive,action:{"done".postln;});

//play the percussive
~percussive.play;

//play the harmonic
~harmonic.play;

(
// See which parts of the Waveform are in which component
// blue = harmonic, orange = percussive
~fw = FluidWaveform(bounds:Rect(0,0,1600,400));
~fw.addAudioLayer(~harmonic,FluidViewer.categoryColors[0].alpha_(0.5));
~fw.addAudioLayer(~percussive,FluidViewer.categoryColors[1].alpha_(0.5));
~fw.front;
)

// real time

b = Buffer.read(s,FluidFilesPath("Tremblay-ASWINE-ScratchySynth-M.wav"));

// hear original
b.play;

// process the "harmonic" part separately from the "percussive" part
(
y = {
    arg which = 1;
    var src = PlayBuf.ar(1,b,BufRateScale.kr(b),loop:1);
    var harm, perc, residual;

    // FluidHPSS will always output a resdiual stream, but if using maskingMode 0 or 1, the residual will be silent.
    # harm, perc, residual = FluidHPSS.ar(src,37,11,maskingMode:1);
    harm = PitchShift.ar(harm,pitchRatio:LFDNoise0.kr(1).midiratio);
    harm = Pan2.ar(harm,SinOsc.kr(0.3));
    harm = FreeVerb2.ar(harm[0],harm[1],0.9,0.9,0.1);
    harm + Pan2.ar((PitchShift.ar(perc,pitchRatio:0.2) * 10).softclip * 0.3,LFDNoise0.kr(1));
}.play;
)

// try it with some straight ahead drums:
b = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));