import AppKit
import SwiftUI

final class SettingsState:ObservableObject {
    @Published var enabled=false
    @Published var status="效果已关闭"
    @Published var automaticCapture=UserDefaults.standard.object(forKey:"automaticCapture") as? Bool ?? true
    @Published var meetingAvoidance=UserDefaults.standard.object(forKey:"meetingAvoidance") as? Bool ?? true
    @Published var meetingApps=Set(UserDefaults.standard.stringArray(forKey:"meetingApps") ?? MeetingApp.supported.map(\.id))
    @Published var meetingBlocker:String?
    @Published var strength:Double
    var onToggle:((Bool)->Void)?
    var onStrength:((Double)->Void)?
    var onOptionsChanged:(()->Void)?
    init() {
        let saved=UserDefaults.standard.object(forKey:"effectStrength") as? Double ?? 1
        strength=min(1,max(0.25,saved))
    }
}

struct SettingsPage:View {
    @ObservedObject var state:SettingsState
    var body:some View {
        VStack(spacing:0) {
            Form {
                Section {
                    Toggle("开合效果",isOn:Binding(get:{state.enabled},set:{state.onToggle?($0)}))
                        .toggleStyle(.switch)
                    Text(state.status).font(.callout).foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            Text("效果强度")
                            Spacer()
                            Text(state.strength,format:.percent.precision(.fractionLength(0)))
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value:Binding(get:{state.strength},set:{state.onStrength?($0)}),in:0.25...1)
                            .accessibilityLabel("效果强度")
                    }
                }
                Section {
                    Toggle("自动选择内置屏幕",isOn:$state.automaticCapture)
                        .toggleStyle(.switch).onChange(of:state.automaticCapture) { _,_ in state.onOptionsChanged?() }
                    Text("首次需系统屏幕录制授权。授权有效时，开启效果无需再选屏；关闭此项可使用系统选屏。")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("屏幕录制权限…") {
                        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {NSWorkspace.shared.open(url)}
                    }
                }
                Section {
                    Toggle("会议软件运行时关闭效果",isOn:$state.meetingAvoidance)
                        .toggleStyle(.switch).onChange(of:state.meetingAvoidance) { _,_ in state.onOptionsChanged?() }
                    if state.meetingAvoidance {
                        Menu("选择会议软件") {
                            ForEach(MeetingApp.supported) { app in
                                Toggle(app.name,isOn:Binding(get:{state.meetingApps.contains(app.id)},set:{ enabled in
                                    if enabled {state.meetingApps.insert(app.id)} else {state.meetingApps.remove(app.id)}
                                    state.onOptionsChanged?()
                                }))
                            }
                        }
                        Text(state.meetingBlocker.map{"\($0) 正在运行，暂不启用效果"} ?? "按软件运行状态保守避让，不代表检测到正在共享。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                Section {
                    LabeledContent("关闭效果",value:"Esc")
                    Text("画面仅在本机内存处理，不保存、不上传。关闭效果即停止采集；系统中断采集时也会自动关闭。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Text("DuoFlip \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button("退出 DuoFlip") {NSApp.terminate(nil)}
            }.padding(16)
        }
        .frame(width:380,height:590)
    }
}

final class SettingsPopoverController:NSObject,NSPopoverDelegate {
    private let popover=NSPopover()
    var isShown:Bool {popover.isShown}
    init(state:SettingsState) {
        super.init()
        popover.contentViewController=NSHostingController(rootView:SettingsPage(state:state))
        popover.contentSize=NSSize(width:380,height:590)
        popover.behavior = .transient
        popover.animates=true
        popover.delegate=self
    }
    func toggle(relativeTo anchor:NSView) {
        if popover.isShown {close();return}
        popover.show(relativeTo:anchor.bounds,of:anchor,preferredEdge:.minY)
        popover.contentViewController?.view.window?.makeKey()
    }
    func close() {popover.performClose(nil)}
    func popoverShouldDetach(_ popover:NSPopover)->Bool {false}
}
