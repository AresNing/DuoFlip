import AppKit
import SwiftUI

final class SettingsState:ObservableObject {
    @Published var enabled=false
    @Published var status:LocalizedMessage="Effect is off"
    @Published var language=L10n.selection
    var onLanguageChanged:(()->Void)?
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
    private var meetingMessage:LocalizedMessage {
        if let blocker=state.meetingBlocker {return "\(LocalizedMessage(key:blocker)) is running · Effect stays off"}
        return "Stops while selected apps are running, even without a meeting. Does not detect screen sharing."
    }
    var body:some View {
        VStack(spacing:0) {
            Form {
                Section {
                    Toggle(L10n.text("Lid effect"),isOn:Binding(get:{state.enabled},set:{state.onToggle?($0)}))
                        .toggleStyle(.switch)
                    Text(state.status.rendered()).font(.callout).foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:8) {
                        HStack {
                            Text(L10n.text("Effect strength"))
                            Spacer()
                            Text(state.strength,format:.percent.precision(.fractionLength(0)))
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value:Binding(get:{state.strength},set:{state.onStrength?($0)}),in:0.25...1)
                            .accessibilityLabel(L10n.text("Effect strength"))
                    }
                }
                Section {
                    Toggle(L10n.text("Select built-in display automatically"),isOn:$state.automaticCapture)
                        .toggleStyle(.switch).onChange(of:state.automaticCapture) { _,_ in state.onOptionsChanged?() }
                    Text(L10n.text("Requires screen-recording permission on first use. Turn this off to choose a screen each time."))
                        .font(.callout).foregroundStyle(.secondary)
                    Button(L10n.text("Screen Recording Settings…")) {
                        if let url=URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {NSWorkspace.shared.open(url)}
                    }
                }
                Section {
                    Toggle(L10n.text("Stop for meeting apps"),isOn:$state.meetingAvoidance)
                        .toggleStyle(.switch).onChange(of:state.meetingAvoidance) { _,_ in state.onOptionsChanged?() }
                    if state.meetingAvoidance {
                        Menu(L10n.text("Choose meeting apps")) {
                            ForEach(MeetingApp.supported) { app in
                                Toggle(L10n.text(app.name),isOn:Binding(get:{state.meetingApps.contains(app.id)},set:{ enabled in
                                    if enabled {state.meetingApps.insert(app.id)} else {state.meetingApps.remove(app.id)}
                                    state.onOptionsChanged?()
                                }))
                            }
                        }
                        Text(meetingMessage.rendered())
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                Section {
                    Picker(L10n.text("Language"),selection:$state.language) {
                        ForEach(AppLanguage.allCases) {language in
                            Text(language.title).tag(language)
                        }
                    }.onChange(of:state.language) {_,value in
                        L10n.selection=value;state.onLanguageChanged?()
                    }
                    LabeledContent(L10n.text("Turn off effect"),value:"Esc")
                    Text(L10n.text("Images stay in local memory. Nothing is saved or uploaded. Turning off the effect or a capture interruption stops capture."))
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            // Recreate cached native menus when the language changes.
            .id(L10n.language)
            .environment(\.locale,Locale(identifier:L10n.language.rawValue))
            Divider()
            HStack {
                Text("DuoFlip \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Quit DuoFlip")) {NSApp.terminate(nil)}
            }.padding(16)
        }
        .frame(width:410,height:690)
    }
}

final class SettingsPopoverController:NSObject,NSPopoverDelegate {
    private let popover=NSPopover()
    var isShown:Bool {popover.isShown}
    init(state:SettingsState) {
        super.init()
        popover.contentViewController=NSHostingController(rootView:SettingsPage(state:state))
        popover.contentSize=NSSize(width:410,height:690)
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
