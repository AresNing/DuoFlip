import AppKit
import MetalKit

final class DesktopController {
    private let capture=DesktopCapture()
    private let renderer:EffectRenderer
    private let metal:MTLDevice
    private let menuOnly:Bool
    private var productName:String {menuOnly ? "DuoFlip":"翻盖"}
    private let inactiveIcon=DuoFlipMark.menuImage(enabled:false)
    private let activeIcon=DuoFlipMark.menuImage(enabled:true)
    private var policy=DesktopPolicy()
    private var overlay:ExperienceWindow?
    private var effect:EffectView?
    private var previousApp:NSRunningApplication?
    private var paused=false
    private var userPaused=false
    private var starting=false
    private var restoring=false
    private var overlayStarted=0.0
    private let statusItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    private var statusMenuLine=NSMenuItem(title:"桌面效果未启用",action:nil,keyEquivalent:"")
    private let toggleItem=NSMenuItem(title:"启用桌面效果…",action:nil,keyEquivalent:"")
    private let stopItem=NSMenuItem(title:"停止并结束共享",action:nil,keyEquivalent:"")
    private(set) var shownCount=0
    private(set) var restoredCount=0
    private(set) var status="桌面效果未启用"
    var onReturn:(()->Void)?
    var automaticCapture=false
    var onEnable:(()->Void)?
    var onSettings:((NSView)->Void)?
    var onActivityChanged:(()->Void)?
    var onEvent:((String)->Void)?
    var onRendered:((Double)->Void)?
    var armed:Bool {policy.armed}
    var selecting:Bool {capture.selecting}
    var needsSensor:Bool {armed || selecting || starting}
    var metrics:[String:Any] {[
        "automaticCapture":automaticCapture,"automaticPermission":capture.automaticPermission,
        "desktopArmed":armed,"desktopSelecting":selecting,"desktopOverlayVisible":overlay != nil,
        "desktopNeedsOpen":policy.needsOpen,"desktopPaused":paused,
        "desktopUserPaused":userPaused,"desktopStarting":starting,
        "menuIconTemplate":statusItem.button?.image?.isTemplate ?? false,
        "menuIconEnabled":armed,"menuBarTitle":statusItem.button?.title ?? "",
        "desktopCapturedFrames":capture.frameCount,"desktopHasFrame":capture.hasFrame,
        "desktopOverlayCount":shownCount,"desktopRestoreCount":restoredCount,
        "desktopCaptureWidth":Int(capture.dimensions.width),"desktopCaptureHeight":Int(capture.dimensions.height),
        "desktopStatus":status]}
    init(renderer:EffectRenderer,metal:MTLDevice,menuOnly:Bool=false) {
        self.renderer=renderer;self.metal=metal;self.menuOnly=menuOnly
        statusItem.button?.title=productName
        let menu=NSMenu();menu.autoenablesItems=false
        statusMenuLine.isEnabled=false
        menu.addItem(statusMenuLine);menu.addItem(.separator())
        toggleItem.target=self;toggleItem.action=#selector(toggleFromMenu);menu.addItem(toggleItem)
        if !menuOnly {
            stopItem.target=self;stopItem.action=#selector(stopFromMenu);menu.addItem(stopItem)
            let controls=NSMenuItem(title:"打开控制窗口",action:#selector(showControls),keyEquivalent:"")
            controls.target=self;menu.addItem(controls)
        } else {
            let hint=NSMenuItem(title:"Esc 关闭效果 · 应用继续常驻",action:nil,keyEquivalent:"")
            hint.isEnabled=false;menu.addItem(hint)
            let sharing=NSMenuItem(title:"开启时读取桌面，关闭即停止",action:nil,keyEquivalent:"")
            sharing.isEnabled=false;menu.addItem(sharing)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle:menuOnly ? "退出应用":"退出翻盖动画验证",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"")
        if menuOnly {
            statusItem.button?.target=self;statusItem.button?.action=#selector(showSettings)
            statusItem.button?.sendAction(on:[.leftMouseUp])
            statusItem.button?.toolTip="DuoFlip · 单击打开设置"
            statusItem.button?.setAccessibilityLabel("DuoFlip，单击打开设置")
        } else {statusItem.menu=menu}
        updateMenu()
        capture.onReady = {[weak self] in
            guard let self else{return}
            if !self.policy.armed {self.policy.enable()}
            self.paused=false;self.userPaused=false;self.starting=false
            self.setStatus("已启用 · 打开至正常角度后合盖触发")
            if !self.menuOnly {NSApp.hide(nil)}
            self.onEvent?("desktop-stream-ready")
        }
        capture.onCancelled = {[weak self] in self?.stop(message:"已取消桌面共享");self?.onReturn?()}
        capture.onFailure = {[weak self] message in self?.stop(message:message);self?.onReturn?()}
        capture.onEvent = {[weak self] event in
            guard let self else{return}
            self.onEvent?(event)
            if event == "desktop-content-unavailable" {self.stop(message:"桌面内容已暂停，旧画面已清除")}
        }
    }
    private func updateMenu() {
        if menuOnly {
            statusItem.button?.title=""
            statusItem.button?.image=armed ? activeIcon:inactiveIcon
            statusItem.button?.imagePosition = .imageOnly
            let state=armed ? "效果已开启":"效果已关闭"
            statusItem.button?.toolTip="DuoFlip · "+state+" · 单击打开设置"
            statusItem.button?.setAccessibilityLabel("DuoFlip，"+state+"，单击打开设置")
        } else {
            statusItem.button?.title=armed ? productName+" · 开" : (userPaused ? productName+" · 暂停":productName)
        }
        toggleItem.title=menuOnly ? (armed || selecting || starting ? "关闭效果":"开启效果…") : (armed ? "暂停桌面效果" : (userPaused ? "恢复桌面效果":"启用桌面效果…"))
        toggleItem.isEnabled = menuOnly || (!selecting && !starting)
        stopItem.isEnabled=armed || userPaused || selecting || starting
        onActivityChanged?()
    }
    private func setStatus(_ value:String) {status=value;statusMenuLine.title=value;updateMenu()}
    func start() {
        if automaticCapture {
            stop(message:"正在自动连接内置屏幕…")
            capture.startAutomatic();updateMenu();return
        }
        if userPaused,capture.canResume {
            userPaused=false;starting=true;setStatus("正在恢复桌面效果…");capture.refresh()
        } else {choose()}
    }
    private func choose() {stop(message:"正在等待系统共享选择");capture.choose();updateMenu()}
    func pauseByUser() {
        guard armed || starting else{return}
        policy.disable();paused=false;starting=false;userPaused=capture.canResume
        capture.pause();hideOverlay(restoreFocus:true)
        setStatus("已暂停 · 菜单栏可恢复");onEvent?("desktop-user-paused")
    }
    @objc private func toggleFromMenu() {
        if menuOnly,needsSensor {stop()}
        else if armed {pauseByUser()}
        else {onEnable?()}
    }
    @objc func showSettings() {if let button=statusItem.button {onSettings?(button)}}
    @objc private func stopFromMenu() {stop()}
    @objc private func showControls() {pauseByUser();onReturn?()}
    func update(angle:Double?,progress:Double,strength:Double,suspended:Bool) {
        guard armed else{return}
        if suspended {suspend();return}
        if capture.stalled {stop(message:"桌面采集无响应，效果已自动关闭");return}
        if paused {
            if let angle,angle>=95 {paused=false;capture.refresh()}
            return
        }
        // An invalid sensor must clear even a snapshot already fading out.
        guard let angle,angle.isFinite else {
            policy.invalidate()
            if overlay != nil {hideOverlay(restoreFocus:true);capture.refresh()}
            return
        }
        let action=policy.update(angle:angle,progress:progress,strength:strength,frameReady:capture.hasFrame || overlay != nil)
        switch action {
        case .show:
            if let effect {
                restoring=false;effect.onSettled=nil
                effect.set(progress:progress,strength:strength)
                break
            }
            guard let id=capture.displayID,
                  let screen=NSScreen.screens.first(where:{($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id}),
                  let frozen=capture.freeze(using:renderer.context),
                  let snapshot=renderer.context.createCGImage(frozen,from:frozen.extent) else {
                policy.invalidate();return
            }
            previousApp=NSWorkspace.shared.frontmostApplication
            let style:NSWindow.StyleMask=menuOnly ? [.borderless,.nonactivatingPanel]:.borderless
            let window=ExperienceWindow(contentRect:screen.frame,styleMask:style,backing:.buffered,defer:false)
            window.hidesOnDeactivate=false
            window.title=menuOnly ? "DuoFlip 桌面效果":"桌面翻盖效果";window.isReleasedWhenClosed=false;window.level = .floating
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
            window.animationBehavior = .none
            window.backgroundColor = .black
            let root=SnapshotEffectSurface(frame:NSRect(origin:.zero,size:screen.frame.size),snapshot:snapshot,renderer:renderer,device:metal)
            let view=root.effect
            view.setAccessibilityLabel("随真实翻盖变化的桌面快照")
            view.set(progress:progress,strength:strength)
            view.onRendered = {[weak self] ms in self?.onRendered?(ms)}
            view.onFirstPresented = {[weak self] in self?.onEvent?("desktop-first-frame-presented")}
            if !menuOnly {
                let exit=NSButton(title:"停止桌面效果（Esc）",target:self,action:#selector(returnToWindow))
                exit.bezelStyle = .rounded;exit.translatesAutoresizingMaskIntoConstraints=false;root.addSubview(exit)
                NSLayoutConstraint.activate([exit.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-25),exit.topAnchor.constraint(equalTo:root.topAnchor,constant:52)])
            }
            window.contentView=root;window.onEscape = {[weak self] in self?.returnToWindow()}
            overlay=window;effect=view;overlayStarted=ProcessInfo.processInfo.systemUptime
            if menuOnly {window.makeKeyAndOrderFront(nil)}
            else {NSApp.unhideWithoutActivation();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
            shownCount+=1;setStatus("桌面过渡中 · Esc 停止")
            onEvent?("desktop-overlay-show")
            DispatchQueue.main.asyncAfter(deadline:.now()+1) { [weak self,weak view] in
                guard let self,let view,self.effect === view,view.waitingForFirstFrame else{return}
                self.stop(message:"画面尚未准备好，已恢复桌面，请重新启用");self.onReturn?()
            }
        case .hide:
            restoring=true
            effect?.onSettled = {[weak self] in
                guard let self,self.restoring else{return}
                self.hideOverlay(restoreFocus:true);self.capture.refresh()
                self.setStatus("已恢复桌面 · 等待下次合盖")
            }
            effect?.set(progress:0,strength:strength)
            // Request a final frame even if the target was already zero.
            effect?.needsDisplay=true
        case .none:
            if !restoring {effect?.set(progress:progress,strength:strength)}
        }
        // Keep the prototype recoverable if it is left partly closed for a long time.
        if overlay != nil,ProcessInfo.processInfo.systemUptime-overlayStarted > 45 {
            stop(message:"本次体验已结束，桌面已恢复");onReturn?()
        }
    }
    private func hideOverlay(restoreFocus:Bool) {
        restoring=false
        guard let window=overlay else{return}
        effect?.stopAnimating();effect?.overrideSource=nil;window.orderOut(nil);window.close();overlay=nil;effect=nil
        restoredCount+=1;onEvent?("desktop-overlay-hide")
        if !menuOnly,restoreFocus,NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            if let previousApp,previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {previousApp.activate(options:[])} else {NSApp.hide(nil)}
        }
        previousApp=nil
    }
    func suspend() {
        guard armed,!paused else{return}
        hideOverlay(restoreFocus:false);policy.invalidate();capture.pause();paused=true
        setStatus("已暂停 · 展开至正常角度后恢复")
        onEvent?("desktop-paused-cleared")
    }
    func stop(message:String="桌面效果已停止") {
        policy.disable();paused=false;userPaused=false;starting=false;capture.stop();hideOverlay(restoreFocus:true);setStatus(message)
        onEvent?("desktop-stopped")
    }
    @objc private func returnToWindow() {stop();onReturn?()}
    func terminate(){stop();NSStatusBar.system.removeStatusItem(statusItem)}
}
