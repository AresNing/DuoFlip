import AppKit
import MetalKit
import CoreImage

// Uses a generated checkerboard; never requests or records the user's desktop.
@main struct FirstFrameCheck {
    static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.accessory)
        let check=Check()
        check.begin()
        withExtendedLifetime(check) {app.run()}
    }
}

final class Check {
    let device=MTLCreateSystemDefaultDevice()!
    lazy var renderer=EffectRenderer(device:device)
    var window:NSWindow?
    var surface:SnapshotEffectSurface?
    var scenario=0
    var presented=0
    var start=0.0
    func begin() {
        let fixture=CIFilter(name:"CICheckerboardGenerator",parameters:["inputWidth":48.0])!.outputImage!.cropped(to:CGRect(x:0,y:0,width:700,height:450))
        let cg=renderer.context.createCGImage(fixture,from:fixture.extent)!
        let frame=NSRect(x:0,y:0,width:700,height:450)
        let surface=SnapshotEffectSurface(frame:frame,snapshot:cg,renderer:renderer,device:device)
        self.surface=surface
        precondition(surface.layer?.contents != nil && surface.effect.layer?.opacity==0)
        surface.effect.set(progress:[0.003,0.5,0.0,0.4][scenario],strength:1)
        // Force a cold first-frame delay while the ordinary snapshot stays visible.
        surface.effect.delegate=nil
        let window=NSWindow(contentRect:frame,styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.animationBehavior = .none
        window.title="DuoFlip 首帧验证（生成棋盘格）";window.contentView=surface
        self.window=window;window.center();window.orderFrontRegardless()
        start=ProcessInfo.processInfo.systemUptime
        surface.effect.onFirstPresented = {[weak self] in
            guard let self,let surface=self.surface else{return}
            precondition(self.scenario != 3,"Cancelled first frame must not reveal a stale layer")
            precondition(!surface.effect.waitingForFirstFrame && surface.effect.layer?.opacity==1)
            self.presented+=1
            print("PASS: scenario \(self.scenario), snapshot covered delayed drawable; presented in \(Int((ProcessInfo.processInfo.systemUptime-self.start)*1000)) ms")
            DispatchQueue.main.asyncAfter(deadline:.now()+0.2) {
                if self.scenario==1 {
                    let began=ProcessInfo.processInfo.systemUptime
                    surface.effect.onSettled = {
                        let elapsed=ProcessInfo.processInfo.systemUptime-began
                        precondition(elapsed>=0.98 && elapsed<2,"Timed restore must complete after one second")
                        print("PASS: native timed restore completed in \(Int(elapsed*1000)) ms")
                        self.finishScenario()
                    }
                    surface.effect.restore()
                } else {self.finishScenario()}
            }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.25) { [self] in
            precondition(surface.effect.waitingForFirstFrame && surface.effect.layer?.opacity==0)
            precondition(surface.layer?.contents != nil)
            surface.effect.delegate=surface.effect
            surface.effect.draw()
            if scenario==3 {
                surface.effect.stopAnimating()
                DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { [self] in
                    precondition(surface.effect.layer?.opacity==0 && presented==3)
                    print("PASS: cancellation while first drawable is pending cannot reveal the stale layer")
                    finishScenario()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+3) { [weak self,weak surface] in
            if let self,let surface,self.surface === surface {fatalError("First frame was never presented")}
        }
    }
    func finishScenario() {
        surface?.effect.stopAnimating();window?.orderOut(nil);window?.close()
        surface=nil;window=nil;scenario+=1
        if scenario==4 {print("PASS: native first-frame lifecycle checks completed");NSApp.terminate(nil)}
        else {begin()}
    }
}
