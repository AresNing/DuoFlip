import AppKit
import MetalKit

@main struct CoreCheck {
    static func main() {
        // Exercise the actual integer/30 Hz input pattern, including intermediate
        // display frames, a held angle, reversal and complete restoration.
        for fps in [60.0,120.0] {
            var eased=EffectMotion(), previous=0.0, movingFrames=0
            for frame in 0..<Int(fps*2) {
                if frame % Int(fps/30)==0 {eased.target=min(1,Double(frame)/fps)}
                eased.advance(1/fps)
                precondition(eased.value>=previous && eased.value<=eased.target)
                if eased.value>previous {movingFrames+=1}
                previous=eased.value
            }
            precondition(eased.settled && movingFrames>Int(fps))
            eased.target=0
            for _ in 0..<Int(fps) {
                eased.advance(1/fps)
                precondition(eased.value>=0 && eased.value<=previous);previous=eased.value
            }
            precondition(eased.value==0 && eased.settled)
        }
        var reversal=EffectMotion();reversal.target=1
        for _ in 0..<4 {reversal.advance(1/60)}
        let before=reversal.value;reversal.target=0
        precondition(reversal.value==before)
        for _ in 0..<60 {reversal.advance(1/60);precondition((0...1).contains(reversal.value))}
        precondition(reversal.settled)
        print("PASS: stepped input interpolated at 60/120 Hz, bounded response, rest, reversal, clear endpoint")
        var state=MotionState()
        precondition(state.progress()==0)
        state.accept(125,at:0);precondition(state.progress()==0)
        state.accept(20,at:1);precondition(state.progress()==1)
        state.accept(55,at:2);precondition(abs(state.progress()-0.5)<0.00001)
        let held=state.progress();state.accept(55,at:2.03);precondition(state.progress()==held)
        state.accept(70,at:2.06);precondition(state.progress()<held)
        state.reset();state.accept(125,at:10);precondition(state.progress()==0)
        state.accept(.nan,at:11);precondition(state.angle==nil && state.progress()==0)
        var prior=1.0
        for angle in 0...180 {let value=state.progress(for:Double(angle));precondition(value>=0 && value<=1 && value<=prior);prior=value}
        var gate=DesktopPolicy()
        gate.enable()
        precondition(gate.update(angle:50,progress:0.5,strength:1,frameReady:true) == .none)
        precondition(gate.update(angle:120,progress:0,strength:1,frameReady:true) == .none)
        precondition(gate.update(angle:60,progress:0.4,strength:1,frameReady:false) == .none)
        precondition(gate.update(angle:60,progress:0.4,strength:1,frameReady:true) == .show)
        precondition(gate.update(angle:65,progress:0.3,strength:1,frameReady:false) == .none)
        precondition(gate.update(angle:92,progress:0,strength:1,frameReady:true) == .hide)
        precondition(gate.update(angle:60,progress:0.4,strength:1,frameReady:true) == .show)
        precondition(gate.update(angle:nil,progress:0,strength:1,frameReady:true) == .hide)
        precondition(gate.needsOpen)
        gate.disable();precondition(gate.update(angle:60,progress:0.4,strength:1,frameReady:true) == .none)
        print("PASS: desktop gating, missing frame, reversal, restoration, stale sensor, disable")
        print("PASS: clamping, trigger range, hold, reversal, wake reset, invalid input, monotonic response")
        precondition(LidAngles().start==90 && LidAngles(0).start==75 && LidAngles(180).start==125)
        precondition(LidAngles(.nan).start==90 && LidAngles(.infinity).start==90 && LidAngles(100.6).start==101)
        // Previously saved values must also fit the range exposed by settings.
        precondition(LidAngles(135).start==125 && LidAngles(124.6).start==125)
        precondition(LidAngles(-.infinity).start==90 && LidAngles(74.4).start==75)
        for start in [75.0,90,110,125] {
            let angles=LidAngles(start), motion=MotionState()
            precondition(motion.progress(for:start,angles:angles)==0)
            precondition(motion.progress(for:20,angles:angles)==1)
            precondition(abs(motion.progress(for:(start+20)/2,angles:angles)-0.5)<0.00001)
            var previous=1.0, policy=DesktopPolicy()
            for angle in 0...180 {
                let progress=motion.progress(for:Double(angle),angles:angles)
                precondition((0...1).contains(progress) && progress<=previous);previous=progress
            }
            func update(_ angle:Double,frameReady:Bool=true)->DesktopPolicy.Action {
                policy.update(angle:angle,progress:motion.progress(for:angle,angles:angles),strength:1,frameReady:frameReady,angles:angles)
            }
            policy.enable()
            precondition(update(start-10) == .none && policy.needsOpen)
            precondition(update(angles.ready-0.1) == .none && policy.needsOpen)
            precondition(update(angles.ready) == .none && !policy.needsOpen)
            precondition(update(angles.show) == .none)
            precondition(update(start-3,frameReady:false) == .none)
            precondition(update(start-3) == .show)
            precondition(update(angles.hide-0.1) == .none && policy.visible)
            precondition(update(angles.hide) == .hide)
            precondition(update(start-3) == .show)
            // Settings changes and sleep both invalidate the existing gesture.
            policy.invalidate()
            precondition(!policy.visible && policy.needsOpen)
            precondition(update(start-3) == .none)
            precondition(update(angles.ready) == .none)
            precondition(update(start-3) == .show)
        }
        var changed=DesktopPolicy();changed.enable()
        _=changed.update(angle:95,progress:0,strength:1,frameReady:true)
        changed.invalidate()
        precondition(changed.update(angle:100,progress:0.4,strength:1,frameReady:true,angles:LidAngles(125)) == .none)
        precondition(changed.needsOpen)
        _=changed.update(angle:130,progress:0,strength:1,frameReady:true,angles:LidAngles(125))
        precondition(changed.update(angle:120,progress:0.01,strength:1,frameReady:true,angles:LidAngles(125)) == .show)
        print("PASS: configurable 75–125° curves, default, normalization, hysteresis, missing frame, and rearming after changes/sleep")
        func sample(_ policy:inout DesktopPolicy,_ angle:Double,_ time:Double,ready:Bool=true)->DesktopPolicy.Action {
            policy.update(angle:angle,progress:MotionState().progress(for:angle),strength:1,frameReady:ready,sampleTime:time,sampleAngle:angle)
        }
        func holding()->DesktopPolicy {
            var policy=DesktopPolicy();policy.enable()
            precondition(sample(&policy,120,0) == .none)
            precondition(sample(&policy,60,1) == .show)
            return policy
        }
        var hold=holding()
        for tick in 1..<45 {
            precondition(sample(&hold,tick % 2 == 0 ? 60:61,1+Double(tick)/30) == .none)
        }
        precondition(sample(&hold,60,2.5) == .restore)
        for tick in 1...90 {precondition(sample(&hold,60,2.5+Double(tick)/30) == .none)}
        precondition(sample(&hold,59,5.6) == .none)
        precondition(sample(&hold,58,5.7,ready:false) == .none)
        precondition(sample(&hold,58,5.8) == .show)
        // A new hold can restore again, including while the first return was interrupted.
        for tick in 1..<45 {precondition(sample(&hold,58,5.8+Double(tick)/30) == .none)}
        precondition(sample(&hold,58,7.31) == .restore)
        precondition(sample(&hold,56,7.4) == .show)
        var slow=holding()
        for tick in 1...90 {
            precondition(sample(&slow,60-Double(tick/15),1+Double(tick)/30) == .none)
        }
        var stale=holding()
        for _ in 0..<100 {precondition(sample(&stale,60,1) == .none)}
        precondition(sample(&stale,60,3) == .none)
        for tick in 1..<45 {precondition(sample(&stale,60,3+Double(tick)/30) == .none)}
        precondition(sample(&stale,60,4.5) == .restore)
        stale.invalidate()
        precondition(sample(&stale,58,4.6) == .none && stale.needsOpen)
        precondition(sample(&stale,120,4.7) == .none)
        precondition(sample(&stale,60,4.8) == .show)
        precondition(stale.update(angle:nil,progress:0,strength:1,frameReady:true) == .hide)
        precondition(sample(&stale,58,5) == .none && stale.needsOpen)
        print("PASS: 1.5s hold, integer jitter, slow closing, duplicate/missing samples, resumed closing, missing frame, repeated hold, invalidation")
        for fps in [30.0,60,120] {
            var timed=EffectMotion();timed.follow(0.8)
            for _ in 0..<120 {timed.advance(1/fps)}
            let initial=timed.value
            timed.restore()
            var previous=initial
            for _ in 0..<Int(fps)-1 {
                timed.advance(1/fps)
                precondition(timed.value<=previous && timed.value>0 && !timed.settled)
                previous=timed.value
            }
            timed.advance(1/fps+0.000001)
            precondition(timed.value==0 && timed.settled)
            timed.follow(0.8)
            for _ in 0..<120 {timed.advance(1/fps)}
            timed.restore();timed.advance(0.5)
            precondition(abs(timed.value-0.4)<0.00001)
            let interrupted=timed.value
            timed.follow(0.9)
            precondition(timed.value==interrupted && !timed.restoring)
            timed.advance(1/fps)
            precondition(timed.value>interrupted && timed.value<0.9)
        }
        print("PASS: one-second monotonic reverse at 30/60/120 Hz, midpoint, and continuous interruption")
    }
}
