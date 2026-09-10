import Foundation

// The overlay must never appear immediately after authorization, wake, or a read error.
// Require one normal open reading before a new closing gesture can trigger it.
struct DesktopPolicy {
    enum Action:Equatable {case none,show,hide}
    private(set) var armed=false
    private(set) var visible=false
    private(set) var needsOpen=true
    mutating func enable(){armed=true;visible=false;needsOpen=true}
    mutating func disable(){armed=false;visible=false;needsOpen=true}
    mutating func invalidate(){visible=false;needsOpen=true}
    mutating func update(angle:Double?,progress:Double,strength:Double,frameReady:Bool)->Action {
        guard armed else{return .none}
        guard let angle,angle.isFinite else {
            let was=visible;invalidate();return was ? .hide:.none
        }
        if needsOpen {
            if angle>=95 {needsOpen=false}
            return .none
        }
        if visible {
            if angle>=91 || strength<=0 {visible=false;return .hide}
        } else if angle<88,progress>0.001,strength>0,frameReady {
            visible=true;return .show
        }
        return .none
    }
}
