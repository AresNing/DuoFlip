import Foundation
@main struct Check {
    static func main() {
        let selected=Set(MeetingApp.supported.map(\.id))
        for id in ["com.electron.lark","com.tencent.meeting","us.zoom.xos","com.microsoft.teams2"] {
            precondition(MeetingProtection.blocker(enabled:true,selected:selected,runningBundleIDs:[id]) != nil)
        }
        precondition(MeetingProtection.blocker(enabled:true,selected:selected,runningBundleIDs:["com.microsoft.teams2.helper"]) == "Microsoft Teams")
        precondition(MeetingProtection.blocker(enabled:true,selected:selected,runningBundleIDs:["com.microsoft.teams2fake","com.google.Chrome","local.codex.LidMotionLab"]) == nil)
        precondition(MeetingProtection.blocker(enabled:false,selected:selected,runningBundleIDs:["com.electron.lark"]) == nil)
        precondition(MeetingProtection.blocker(enabled:true,selected:["zoom"],runningBundleIDs:["com.electron.lark"]) == nil)
        precondition(MeetingProtection.blocker(enabled:true,selected:selected,runningBundleIDs:[]) == nil)
        print("PASS: selected conference apps, helper IDs, exact boundaries, deselection, disabled protection, and no false browser/own-app match")
    }
}
