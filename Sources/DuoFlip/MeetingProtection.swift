import Foundation

// Conservative application-presence policy, NOT a screen-sharing detector.
struct MeetingApp:Identifiable {
    let id:String
    let name:String
    let bundleIDs:[String]
    static let supported:[MeetingApp] = [
        .init(id:"lark",name:"飞书 / Lark",bundleIDs:["com.electron.lark","com.bytedance.feishu"]),
        .init(id:"tencent",name:"腾讯会议",bundleIDs:["com.tencent.meeting"]),
        .init(id:"zoom",name:"Zoom",bundleIDs:["us.zoom.xos"]),
        .init(id:"teams",name:"Microsoft Teams",bundleIDs:["com.microsoft.teams","com.microsoft.teams2"])
    ]
}
struct MeetingProtection {
    static func blocker(enabled:Bool,selected:Set<String>,runningBundleIDs:[String])->String? {
        guard enabled else{return nil}
        return MeetingApp.supported.first { app in
            selected.contains(app.id) && runningBundleIDs.contains { running in
                app.bundleIDs.contains {running == $0 || running.hasPrefix($0+".")}
            }
        }?.name
    }
}
