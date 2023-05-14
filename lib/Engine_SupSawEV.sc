// CroneEngine_SupSawEV
// supersaw code:
// from: https://gist.github.com/audionerd/fe50790b7601cba65ddd855caffb05ad
// via https://web.archive.org/web/20191104212834/https://www.nada.kth.se/utbildning/grukth/exjobb/rapportlistor/2010/rapporter10/szabo_adam_10131.pdf

//emulation of erbeverb reverb by alanza: https://discord.com/channels/765746584582750248/789941892812242954/1099343587205972091

Engine_SupSawEV : CroneEngine {
  var voiceGroup;
  var <voices;
  var <effects;
  var effectsBus;
  var controlBus;
  var <routine;
  var num_notes = 7;
  var notes = #[60, 61, 63, 65, 72, 84, 32];
  var ampEV = 0.5;
  var mixEV = 0.5;
  var detuneEV = 0.5;
  var cutoffMin=400;
  var cutoffMax=8500;
  
  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }
  
  alloc {
    voiceGroup = Group.head(context.xg);
    voices = Array.new();
    
    effectsBus = Bus.audio(context.server, 1);
    
    SynthDef(\superSaw,{
      arg out,freq = 523.3572, mix=0.75, detune = 0.75, amp=1,
      cutoffMin=400,cutoffMax=8500;
      var env = Env(
        levels: [0, 0.1, 1, 0.2],
        times: [0.5, 3, 3],
        curve: 8);

      var detuneCurve = { |x|
        (10028.7312891634*x.pow(11)) -
        (50818.8652045924*x.pow(10)) +
        (111363.4808729368*x.pow(9)) -
        (138150.6761080548*x.pow(8)) +
        (106649.6679158292*x.pow(7)) -
        (53046.9642751875*x.pow(6)) +
        (17019.9518580080*x.pow(5)) -
        (3425.0836591318*x.pow(4)) +
        (404.2703938388*x.pow(3)) -
        (24.1878824391*x.pow(2)) +
        (0.6717417634*x) +
        0.0030115596
      };
      var centerGain = { |x| (-0.55366 * x) + 0.99785 };
      var sideGain = { |x| (-0.73764 * x.pow(2)) + (1.2841 * x) + 0.044372 };
      var center,detuneFactor, freqs, side, sig;

      center = LFSaw.ar(freq, Rand());
      detuneFactor = freq * detuneCurve.(detune);
      freqs = [
        (freq - (detuneFactor * 0.11002313)),
        (freq - (detuneFactor * 0.06288439)),
        (freq - (detuneFactor * 0.01952356)),
        // (freq + (detuneFactor * 0)),
        (freq + (detuneFactor * 0.01991221)),
        (freq + (detuneFactor * 0.06216538)),
        (freq + (detuneFactor * 0.10745242))
      ];
      side = Mix.fill(6, { |n|
        LFSaw.ar(freqs[n], Rand(0, 2))
      });

      sig = (center * centerGain.(mix)) + (side * sideGain.(mix));

      sig = HPF.ar(sig ! 2, freq);


      //////////////////
      //add-ons
      /////////////////
      // moog ladder filter
      sig = MoogLadder.ar(Mix(sig ! 2), LinExp.kr(LFCub.kr(0.1, 0.5*pi), -1, 1, cutoffMin, cutoffMax), 0.75);

      sig = Limiter.ar(sig, 0.3, 0.01);
      
      Out.ar(out,sig*amp*EnvGen.kr(env,doneAction: Done.freeSelf));
      // Out.ar(out,sig*amp);
    }).add; // superSaw SynthDef
      

    //effects
    effects = SynthDef(\effects, {
      
      //ErbeVerb emulation
      arg in, out;
      var input = In.ar(in, 1);
      var decay = \decay.kr(0.3);
      var absorb = 100 * (200 ** \absorb.kr(0.1));
      var modulation = \modulation.kr(0.01);
      var loop = LocalIn.ar(4);
      var allpassTime = [0.015, 0.007, 0.011, 0.002];
      var delayTime = \delay.kr(0.3) + [0, 0.002, 0.003, 0.005];
      var modulator = SinOsc.kr(\modrate.kr(0.05), [0, 0.5, 0.75, 1], mul:modulation);
      
      
  
      2.do({ arg i;
        loop[i] = loop[i] + input;
      });
      4.do({ arg i;
        var snd = loop[i];
        snd = SVF.ar(snd, absorb, 0.1, 1);
        snd = AllpassC.ar(snd, 0.015, modulator[i].madd(allpassTime[i], allpassTime[i]), 0.015);
        loop[i] = DelayC.ar(snd, 3, modulator[i].madd(delayTime[i], delayTime[i]));
      });

      ReplaceOut.ar(out, [loop[0] + loop[3], loop[1] + loop[2]]);
      loop = [loop[0] - loop[1], loop[0] + loop[1], loop[2] - loop[3], loop[2] + loop[3]];
      loop = [loop[0] - loop[2], loop[0] + loop[2], loop[1] - loop[3], loop[1] + loop[3]];
      LocalOut.ar(loop * decay);
    }).play(target: context.xg, args: [\in, effectsBus, \out, context.out_b], addAction: \addToTail);



    context.server.sync;
    
    routine = Routine({  
      loop({

        var a = Prand(notes, inf).asStream;
	      var nextnote = a.next.midicps;
        var newVoice = Synth.new(\superSaw,
          [
            \freq, nextnote,
            \mix, mixEV,
            \detune, detuneEV,
            \amp, ampEV,
            \out, effectsBus,
          ],
          target: voiceGroup).onFree({ 
            // (["free newVoice",newVoice]).postln;
            voices.remove(newVoice); 
          });
        // (["ampEV",ampEV]).postln;
        // (["voices",voices]).postln;
        voices.addFirst(newVoice);
        
        2.wait;
      });
    }).play();

    //voice commands
    this.addCommand("amp", "f", { arg msg;
      ampEV = msg[1];
      voiceGroup.set(\amp, ampEV);
    });

    this.addCommand("mix", "f", { arg msg;
      mixEV = msg[1];
      voiceGroup.set(\mix, mixEV);
    });

    this.addCommand("detune", "f", { arg msg;
      detuneEV = msg[1];
      voiceGroup.set(\detune, detuneEV);
    });

    this.addCommand("cutoffMin", "f", { arg msg;
      cutoffMin = msg[1];
      voiceGroup.set(\cutoffMin, cutoffMin);
    });

    this.addCommand("cutoffMax", "f", { arg msg;
      cutoffMax = msg[1];
      voiceGroup.set(\cutoffMax, cutoffMax);
    });


    //reverb commands
    this.addCommand("decay", "f", { arg msg;
      effects.set(\decay, LinLin.kr(msg[1],0,127,0,0.9));
    });

    this.addCommand("absorb", "f", { arg msg;
      effects.set(\absorb, LinLin.kr(msg[1],0,127,0,3));
    });

    this.addCommand("modulation", "f", { arg msg;
      effects.set(\modulation, LinLin.kr(msg[1],0,127,0,1));
    });

    this.addCommand("modRate", "f", { arg msg;
      effects.set(\modRate, LinLin.kr(msg[1],0,127,0,1));
    });

    this.addCommand("delay", "f", { arg msg;
      effects.set(\delay, LinLin.kr(msg[1],0,127,0,5));
    });

    //note commands
    this.addCommand("update_num_notes", "f", { arg msg;
      num_notes = msg[1];
    });

    this.addCommand("update_notes", "ffffffffffffffffffffffff", { arg msg;
      var newNotes = Array.new(num_notes);
      var scale;
      for (0, num_notes-1, { arg i;
        var val = msg[i+1];
        if (val>=0, {
          newNotes.insert(i,val)
          });
      }); 
      notes=newNotes;
      (["update scale",notes]).postln;
    });

    //stop/start
    this.addCommand("stop", "f", { arg msg;
      routine.stop();
    });
    
    this.addCommand("start", "f", { arg msg;
      routine.value();
    });

  }

  free {
    ("free objects").postln;
    voices.do { |v|
      v.free
      // (["free voices", v]).postln;
    };   
    routine.stop;
    voiceGroup.free;
    effects.free;
    effectsBus.free;
    controlBus.free;
  }
}
