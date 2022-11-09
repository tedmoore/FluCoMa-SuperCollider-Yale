(
~trombone = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"));
~oboe = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
)

~trombone.play;
~oboe.play;

( // load the first ~41 seconds for training the neural network
~trombone_train = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"),0,1783040);
~oboe_train = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"),0,1783040);

// load the rest to use for testing the neural network
~trombone_test = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"),1783040);
~oboe_test = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"),1783040);
)

(
~nmfccs = 13;
~mfccbuf = Buffer.alloc(s,~nmfccs);
~timbredata = FluidDataSet(s);
~labels = FluidLabelSet(s);
~counter = 0;
~realtime_analysis = {
	arg buf;
	{
		var sig = PlayBuf.ar(1,buf,BufRateScale.ir(buf),doneAction:2);
		var mfccs = FluidMFCC.kr(sig,~nmfccs,startCoeff:1,maxNumCoeffs:~nmfccs);
		FluidKrToBuf.kr(mfccs,~mfccbuf);
		sig.dup;
	}.play;
};
~add_point = {
	arg label;
	var id = "example-%".format(~counter);
	~timbredata.addPoint(id,~mfccbuf);
	~labels.addLabel(id,label);
	~counter = ~counter + 1;
};
)

~timbredata.print;
~labels.print;
~timbredata.clear;
~labels.clear;

// play the playback+analysis function with the trombone sound
~realtime_analysis.(~trombone_train);
// execute the add point function as many times as you want points
~add_point.("trombone");

// do the same with the oboe sound
~realtime_analysis.(~oboe_train);
// and add a similar number of points
~add_point.("oboe");

// create a classifier
(
~nn = FluidMLPClassifier(s,hiddenLayers:[5],activation:1,maxIter:1000,learnRate:0.1,momentum:0.9,batchSize:5,validation:0);
)

// run this fitting function for as long as the error is not acceptable
(
~continue_training = true;
~train = {
	~nn.fit(~timbredata,~labels,{
		arg loss;
		loss.postln;
		if(~continue_training){
			~train.();
		};
	});
};
~train.();
)

// when ready to stop training, run this line
~continue_training = false;

// define a querying function on the synth
(
~predictions = Buffer.alloc(s,1);
~server_predictions = {
	arg buf;
	OSCdef(\predictions,{
		arg msg;
		msg[3].postln;
	},"/prediction");
	{
		var sig = PlayBuf.ar(1,buf,BufRateScale.ir(buf),doneAction:2);
		var mfccs = FluidMFCC.kr(sig,~nmfccs,startCoeff:1,maxNumCoeffs:~nmfccs);
		var loudness = FluidLoudness.kr(sig)[0];
		var thresh = -40;
		var isPredicting = (loudness >= thresh);
		var trig = Impulse.kr(30);
		FluidKrToBuf.kr(mfccs,~mfccbuf);
		~nn.kr(trig * isPredicting,~mfccbuf,~predictions);
		SendReply.kr(trig * isPredicting,"/prediction",FluidBufToKr.kr(~predictions));
		SendReply.kr(trig * (1-isPredicting),"/prediction",-1);
		sig.dup;
	}.play;
};
)

// run it with trombone test sounds...
~server_predictions.(~trombone_test);
// ... and with oboe test sounds
~server_predictions.(~oboe_test);

// ====================== language side query ============================
// one could also query on the language side and get the label back as symbol
~realtime_analysis.(~trombone_test);
~realtime_analysis.(~oboe_test);

// execute the code below
(
~nn.predictPoint(~mfccbuf,{
	arg label;
	label.postln;
});
)

// ================== automating the analysis =============================
(
~remove_silence = {
	arg src, action;
	var concat_buf = Buffer(s);
	var indices = Buffer(s);
	FluidBufAmpGate.processBlocking(s,src,indices:indices,onThreshold:-20,offThreshold:-30,minSliceLength:0.1*s.sampleRate,minSilenceLength:0.1*s.sampleRate,rampDown:0.01*s.sampleRate);
	indices.loadToFloatArray(action:{
		arg fa;
		fork{
			var current_frame = 0;

			// this array is initally flat, but is alternating [ onset0 , offset0 , onset1 , offset1 , onset2 ... ],
			// so by using .clump(2) we clump each onset and offest together to get an array like this:
			// [ [ onset0 , offset0 ] , [ onset1 , offset1 ] , [ onset2 , offset2 ] , ... ]
			fa = fa.clump(2);

			fa.do{
				arg arr, i;
				var startFrame = arr[0];
				var numFrames = arr[1] - startFrame;
				"%\tstart: %\tend: %".format(i,startFrame,numFrames).postln;
				FluidBufCompose.processBlocking(s,src,startFrame,numFrames,destination:concat_buf,destStartFrame:current_frame);
				current_frame = current_frame + numFrames;
			};

			s.sync;

			indices.free;
			src.free;

			action.(concat_buf);
		};
	});
};
)

// peek at where the silence is
(
FluidWaveform(~trombone_train);
FluidWaveform(~oboe_train);
)

(
~remove_silence.(~trombone_train,{arg rs; ~trombone_train = rs});
~remove_silence.(~oboe_train,{arg rs; ~oboe_train = rs});
)

// analyze every FFT frame in the buffer
(
~analyze_buffer = {
	arg src, label;
	fork{
		var features = Buffer(s);
		var flatbuf = Buffer(s);
		FluidBufMFCC.processBlocking(s,src,numCoeffs:~nmfccs,features:features,startCoeff:1);
		s.sync;
		features.numFrames.do{
			arg i;
			var id = "%-%".format(label,i);
			FluidBufFlatten.processBlocking(s,features,i,1,destination:flatbuf);
			~timbredata.addPoint(id,flatbuf);
			~labels.addLabel(id,label);
		};
		s.sync;
		features.free;
		flatbuf.free;
	};
};
)

// clear the dataset and label set to start fresh
(
~timbredata.clear;
~labels.clear;
)

// analyze!
(
~analyze_buffer.(~trombone_train,"trombone");
~analyze_buffer.(~oboe_train,"oboe");
)

// is there stuff in there?
(
~timbredata.print;
~labels.print;
)