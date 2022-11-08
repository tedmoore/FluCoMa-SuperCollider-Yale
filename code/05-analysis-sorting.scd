// =============== order bass notes by pitch ===================

~src = Buffer.read(s,FluidFilesPath("Tremblay-AaS-AcBassGuit-Melo-M.wav"));

~grain_size_samples = 0.2 * ~src.sampleRate;

(
fork{
	var current_pos_samples = ~grain_size_samples;
	var counter = 0;
	var pitch = Buffer(s);
	var stat = Buffer(s);

	~stats = Buffer(s);

	while{
		current_pos_samples < ~src.numFrames;
	}{
		FluidBufPitch.processBlocking(s,
			source: ~src,
			startFrame: current_pos_samples - ~grain_size_samples,
			numFrames: ~grain_size_samples,
			features: pitch,
			select: [\pitch],
			windowSize:4096,
			hopSize:1024
		);
		FluidBufStats.processBlocking(s,pitch,stats:stat,select:[\mean]);
		FluidBufCompose.processBlocking(s,stat,destination:~stats,destStartFrame:counter);
		counter = counter + 1;
		current_pos_samples = current_pos_samples + ~grain_size_samples;
	};
	s.sync;
	pitch.free;
	stat.free;
	"analysis complete".postln;
};
)

~stats.postln;

(
~stats.loadToFloatArray(action:{
	arg fa;
	fork{
		var order = fa.order;
		order.do{
			arg pos;
			var start_samples = pos * ~grain_size_samples;
			"position: %\tstat: %".format(pos,fa[pos]).postln;
			{
				var sig = PlayBuf.ar(1,~src,1,1,startPos:start_samples);
				var env = EnvGen.kr(Env.sine(0.2),doneAction:2);
				sig = sig * env;
				sig.dup;
			}.play;
			0.1.wait;
		};
	};
});
);

// sort drum hits according to their spectral centroid

// this audio file comes with the flucoma toolkit
~src = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// what does it sound like
~src.play;

// slice the buffer in non real-time
(
~indices = Buffer(s);
FluidBufOnsetSlice.processBlocking(s,~src,metric:9,threshold:0.05,indices:~indices,action:{"done".postln});
)

// how many slice points has it found
~indices.postln;

// look at the slice points
FluidWaveform(~src,~indices);

// a function to play back and individual slice point
(
~play_slice = {
	arg index;
	{
		var startsamp = Index.kr(~indices,index);
		var stopsamp = Index.kr(~indices,index+1);
		var phs = Phasor.ar(0,BufRateScale.ir(~src),startsamp,stopsamp);
		var sig = BufRd.ar(1,~src,phs);
		var dursecs = (stopsamp - startsamp) / BufSampleRate.ir(~src);
		var env = EnvGen.kr(Env([0,1,1,0],[0.03,dursecs-0.06,0.03]),doneAction:2);
		sig.dup * env;
	}.play;
};
)

// analysis
(
~indices.loadToFloatArray(action:{
	arg fa;
	var spec = Buffer(s);
	var stats = Buffer(s);
	var meancentroids = Buffer(s);

	fa.doAdjacentPairs{
		arg start, end, i;
		var num = end - start;
		start.postln;
		end.postln;
		i.postln;

		// analyze a sound slice for spectral centroid
		FluidBufSpectralShape.processBlocking(s,~src,start,num,features:spec,select:[\centroid]);

		// get the mean centroid for this sounds slice
		FluidBufStats.processBlocking(s,spec,stats:stats,select:[\mean]);

		// copy the mean spectral centroid to the appropriate index (destStartFrame) of
		// the buffer called meancentroids
		FluidBufCompose.processBlocking(s,stats,destination:meancentroids,destStartFrame:i);
	};

	s.sync;

	meancentroids.loadToFloatArray(action:{
		arg fa;
		fa.postln;
		fa.size.postln;
		~meancentroids = fa;
	});
});
)

~order = ~meancentroids.order;

(
fork{
	~order.do{
		arg i;
		"playing slice: %".format(i).postln;
		~play_slice.(i);
		1.wait;
	};
}
)