import Foundation

// The overlay must never appear immediately after authorization, wake, or a read error.
// Require one normal open reading before a new closing gesture can trigger it.
struct DesktopPolicy {
    enum Action:Equatable {case none,show,hide,restore}
    private(set) var armed=false
    private(set) var visible=false
    private(set) var needsOpen=true
    private var lastSampleTime:Double?
    private var stableAngle:Double?
    private var stableSince:Double?
    private var resumePeak:Double?
    mutating func enable(){armed=true;invalidate()}
    mutating func disable(){armed=false;invalidate()}
    mutating func invalidate(){visible=false;needsOpen=true;lastSampleTime=nil;stableAngle=nil;stableSince=nil;resumePeak=nil}
    mutating func update(angle:Double?,progress:Double,strength:Double,frameReady:Bool,angles:LidAngles=LidAngles(),sampleTime:Double?=nil,sampleAngle:Double?=nil)->Action {
        guard armed else{return .none}
        guard let angle,angle.isFinite else {
            let was=visible;invalidate();return was ? .hide:.none
        }
        if needsOpen {
            if angle>=angles.ready {needsOpen=false}
            return .none
        }
        // Only fresh sensor samples advance the hold clock. Integer sensor jitter
        // of one degree is tolerated; cumulative motion of two degrees resets it.
        let raw=sampleAngle ?? angle
        let fresh=sampleTime.map { $0.isFinite && (lastSampleTime == nil || $0 > lastSampleTime!) } ?? false
        if fresh,let time=sampleTime {
            if let last=lastSampleTime,time-last>0.5 {stableAngle=nil;stableSince=nil}
            lastSampleTime=time
        }
        if let peak=resumePeak {
            if angle>=angles.hide {resumePeak=nil;stableAngle=nil;stableSince=nil}
            else {
                guard fresh else{return .none}
                resumePeak=max(peak,raw)
                guard peak-raw>=2,progress>0.001,strength>0,frameReady else{return .none}
                resumePeak=nil;visible=true;stableAngle=raw;stableSince=sampleTime
                return .show
            }
        }
        if visible {
            if angle>=angles.hide || strength<=0 {visible=false;stableAngle=nil;stableSince=nil;return .hide}
            if fresh,let time=sampleTime {
                if let anchor=stableAngle,abs(raw-anchor)<2,let since=stableSince {
                    if time-since>=1.5 {
                        visible=false;resumePeak=raw;stableAngle=nil;stableSince=nil
                        return .restore
                    }
                } else {stableAngle=raw;stableSince=time}
            }
        } else if angle<angles.show,progress>0.001,strength>0,frameReady {
            visible=true;stableAngle=fresh ? raw:nil;stableSince=fresh ? sampleTime:nil;return .show
        }
        return .none
    }
}
