import AppKit
import MetalKit

@main struct DuoFlip {
    static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate=MenuBarDelegate();app.delegate=delegate
        withExtendedLifetime(delegate) {app.run()}
    }
}

final class MenuBarDelegate:NSObject,NSApplicationDelegate {
    private var desktop:DesktopController!
    private let settings=SettingsState()
    private var settingsPopover:SettingsPopoverController!
    private var monitor=SensorMonitor()
    private var shortcut=EscapeShortcut()
    private var motion=MotionState()
    private var timer:Timer?
    private var observers=[NSObjectProtocol]()
    private var lastSample:LidSample?
    private var monitoring=false
    private var sleeping=false
    private var lastMeetingCheck=0.0
    // Diagnostics are opt-in for development. Installed apps write no session files.
    private var log:SessionLog?
    func applicationDidFinishLaunching(_ notification:Notification) {
        guard let device=MTLCreateSystemDefaultDevice() else {NSApp.terminate(nil);return}
        if let directory=ProcessInfo.processInfo.environment["LID_LAB_VALIDATION_DIR"] {
            log=try? SessionLog(directory:URL(fileURLWithPath:directory))
        }
        desktop=DesktopController(renderer:EffectRenderer(device:device),metal:device,menuOnly:true)
        settingsPopover=SettingsPopoverController(state:settings)
        desktop.onEnable = {[weak self] in self?.startEffect()}
        desktop.onSettings = {[weak self] anchor in self?.settingsPopover.toggle(relativeTo:anchor)}
        settings.onToggle = {[weak self] enabled in
            guard let self else{return}
            if enabled {self.startEffect()} else {self.desktop.stop()}
        }
        settings.onOptionsChanged = {[weak self] in
            guard let self else{return}
            UserDefaults.standard.set(self.settings.automaticCapture,forKey:"automaticCapture")
            UserDefaults.standard.set(self.settings.meetingAvoidance,forKey:"meetingAvoidance")
            UserDefaults.standard.set(Array(self.settings.meetingApps).sorted(),forKey:"meetingApps")
            if self.desktop.needsSensor,self.desktop.automaticCapture != self.settings.automaticCapture {
                self.desktop.stop(message:"采集方式已更改，请重新开启效果")
            }
            self.checkMeetingProtection()
        }
        settings.onStrength = {[weak self] value in
            guard let self else{return}
            self.settings.strength=value
            UserDefaults.standard.set(value,forKey:"effectStrength")
            self.update()
        }
        desktop.onActivityChanged = {[weak self] in self?.syncActivity()}
        desktop.onRendered = {[weak self] ms in self?.log?.rendered(ms)}
        desktop.onEvent = {[weak self] event in self?.log?.event(event)}
        shortcut.onEscape = {[weak self] in
            self?.settingsPopover.close()
            self?.desktop.stop(message:"效果已关闭 · 单击图标可重新开启")
        }
        monitor.onSample = {[weak self] sample in
            guard let self,self.monitoring,!self.sleeping else{return}
            self.lastSample=sample;self.motion.accept(sample.angle,at:sample.timestamp)
            self.log?.sample(sample,filtered:self.motion.angle ?? sample.angle,progress:self.motion.progress(),live:true)
            self.update()
        }
        monitor.onError = {[weak self] message in
            guard let self,self.monitoring else{return}
            self.desktop.stop(message:message+" · 效果已关闭")
            self.log?.event("error: "+message)
        }
        checkMeetingProtection()
        let center=NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) {[weak self] _ in self?.checkMeetingProtection()})
        }
        for name in [NSWorkspace.willSleepNotification,NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) {[weak self] _ in
                guard let self else{return}
                self.sleeping=true;self.desktop.suspend();self.syncActivity()
            })
        }
        for name in [NSWorkspace.didWakeNotification,NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName:name,object:nil,queue:.main) {[weak self] _ in
                guard let self else{return}
                self.sleeping=false;self.syncActivity()
            })
        }
        let timer=Timer(timeInterval:0.2,repeats:true) {[weak self] _ in
            guard let self else{return}
            if let sample=self.lastSample,ProcessInfo.processInfo.systemUptime-sample.timestamp>0.75 {
                self.lastSample=nil;self.motion.reset()
            }
            if ProcessInfo.processInfo.systemUptime-self.lastMeetingCheck>1 {
                self.checkMeetingProtection()
            }
            self.update();self.flush()
        }
        self.timer=timer;RunLoop.main.add(timer,forMode:.common)
        log?.event("menubar-launch");flush()
        if CommandLine.arguments.contains("--settings") {desktop.showSettings()}
    }
    private func checkMeetingProtection() {
        lastMeetingCheck=ProcessInfo.processInfo.systemUptime
        settings.meetingBlocker=MeetingProtection.blocker(enabled:settings.meetingAvoidance,selected:settings.meetingApps,runningBundleIDs:NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if let blocker=settings.meetingBlocker,desktop.needsSensor {
            desktop.stop(message:blocker+" 正在运行，已自动关闭效果")
            log?.event("meeting-protection-stopped-effect")
        }
    }
    private func startEffect() {
        checkMeetingProtection()
        if let blocker=settings.meetingBlocker {
            desktop.stop(message:blocker+" 正在运行，已避让；可在下方调整会议避让设置")
            return
        }
        settingsPopover.close()
        desktop.automaticCapture=settings.automaticCapture
        desktop.start()
    }
    private func syncActivity() {
        settings.enabled=desktop.needsSensor
        settings.status=desktop.status
        let active=desktop.needsSensor && !sleeping
        if active != monitoring {
            monitoring=active;lastSample=nil;motion.reset()
            if active {monitor.start()} else {monitor.stop()}
        }
        // If Esc cannot be registered, do not leave an effect enabled without its
        // promised global stop control; the settings entry stays available.
        if !shortcut.setEnabled(desktop.needsSensor && !sleeping) {
            desktop.stop(message:"Esc 被其他程序占用 · 效果未开启")
        }
    }
    private func update() {
        desktop.update(angle:lastSample == nil ? nil:motion.angle,progress:motion.progress(),strength:settings.strength,suspended:sleeping)
    }
    private func flush() {
        var state=desktop.metrics
        state.merge(["pid":ProcessInfo.processInfo.processIdentifier,"menuOnly":true,"settingsVisible":settingsPopover.isShown,"settingsPresentation":"menuBarPopover","visibleStandaloneWindows":NSApp.windows.filter{$0.isVisible && $0.styleMask.contains(.titled)}.count,"meetingAvoidance":settings.meetingAvoidance,"meetingBlocked":settings.meetingBlocker != nil,"effectStrength":settings.strength,"sensorMonitoring":monitoring,"sensorAvailable":lastSample != nil,"rawAngle":lastSample?.angle ?? -1,"escapeRegistered":shortcut.isRegistered,"visibleWindows":NSApp.windows.filter{$0.isVisible}.count,"suspended":sleeping]) {_,new in new}
        log?.flush(state:state)
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows:Bool)->Bool {desktop.showSettings();return false}
    func applicationWillTerminate(_ notification:Notification) {
        desktop?.terminate();shortcut.setEnabled(false);monitor.stop();timer?.invalidate()
        for observer in observers {NSWorkspace.shared.notificationCenter.removeObserver(observer)}
        log?.event("quit");flush();log?.finish()
    }
}
