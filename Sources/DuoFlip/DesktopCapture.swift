import AppKit
import ScreenCaptureKit
import CoreImage

// Picker sessions retain their exact grant. Automatic mode requires the OS screen
// recording permission and filters strictly to the built-in display. Frames remain in memory.
final class DesktopCapture:NSObject,SCContentSharingPickerObserver,SCStreamOutput,SCStreamDelegate {
    private var stream:SCStream?
    private var filter:SCContentFilter?
    private let framesQueue=DispatchQueue(label:"local.lid-motion.desktop-frames",qos:.userInitiated)
    private var generation=0
    private var frozen=false
    private var latest:CVPixelBuffer?
    private var receivedAt=0.0
    private var live=false
    private(set) var frameCount=0
    private(set) var displayID:CGDirectDisplayID?
    private(set) var dimensions=CGSize.zero
    private(set) var selecting=false
    private(set) var automaticMode=false
    var automaticPermission:Bool {CGPreflightScreenCaptureAccess()}
    var onReady:(()->Void)?
    var onCancelled:(()->Void)?
    var onFailure:((LocalizedMessage)->Void)?
    var onEvent:((String)->Void)?
    var hasFrame:Bool {live && latest != nil}
    var stalled:Bool {live && ProcessInfo.processInfo.systemUptime-receivedAt>2.5}
    var canResume:Bool {filter != nil && displayID != nil && !selecting}
    override init() {
        super.init();SCContentSharingPicker.shared.add(self)
    }
    func choose() {
        stop();automaticMode=false;selecting=true
        let picker=SCContentSharingPicker.shared
        var config=SCContentSharingPickerConfiguration()
        config.allowedPickerModes = .singleDisplay
        config.allowsChangingSelectedContent=false
        picker.defaultConfiguration=config
        picker.maximumStreamCount=1
        picker.isActive=true
        picker.present(using:.display)
    }
    func startAutomatic() {
        stop();automaticMode=true;selecting=true
        let token=generation
        Task { @MainActor [weak self] in
            do {
                // ScreenCaptureKit performs the system permission flow if needed.
                let content=try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:true)
                guard let self,self.generation==token,self.selecting else{return}
                guard let display=content.displays.first(where:{CGDisplayIsBuiltin($0.displayID) != 0}) else {
                    self.stop();self.onFailure?("Built-in display not found · Effect turned off");return
                }
                let own=content.applications.filter{$0.processID == ProcessInfo.processInfo.processIdentifier}
                let filter=SCContentFilter(display:display,excludingApplications:own,exceptingWindows:[])
                self.selecting=false;self.filter=filter;self.displayID=display.displayID
                let scale=min(Double(filter.pointPixelScale),1920.0/max(1,filter.contentRect.width))
                self.dimensions=CGSize(width:max(2,Int(filter.contentRect.width*scale)/2*2),height:max(2,Int(filter.contentRect.height*scale)/2*2))
                self.onEvent?("desktop-automatic-built-in-selected")
                self.refresh()
            } catch {
                guard let self,self.generation==token else{return}
                let permission=CGPreflightScreenCaptureAccess()
                self.stop()
                self.onFailure?(permission ? "Automatic capture failed · Effect turned off" : "Allow screen recording for DuoFlip in System Settings, then turn on the effect again.")
            }
        }
    }
    func contentSharingPicker(_ picker:SCContentSharingPicker,didUpdateWith filter:SCContentFilter,for stream:SCStream?) {
        DispatchQueue.main.async { [weak self] in
            guard let self,self.selecting else{return}
            self.selecting=false
            guard #available(macOS 15.2,*),filter.style == .display,filter.includedDisplays.count == 1,
                  let display=filter.includedDisplays.first,CGDisplayIsBuiltin(display.displayID) != 0 else {
                self.stop();self.onFailure?("Choose your MacBook’s built-in display in the system picker.");return
            }
            self.filter=filter;self.displayID=display.displayID
            let scale=min(Double(filter.pointPixelScale),1920.0/max(1,filter.contentRect.width))
            self.dimensions=CGSize(width:max(2,Int(filter.contentRect.width*scale)/2*2),height:max(2,Int(filter.contentRect.height*scale)/2*2))
            self.onEvent?("desktop-picker-approved")
            self.refresh()
        }
    }
    func contentSharingPicker(_ picker:SCContentSharingPicker,didCancelFor stream:SCStream?) {
        DispatchQueue.main.async { [weak self] in
            guard let self,self.selecting else{return}
            self.stop();self.onCancelled?()
        }
    }
    func contentSharingPickerStartDidFailWithError(_ error:Error) {
        DispatchQueue.main.async { [weak self] in self?.stop();self?.onFailure?("Could not open the screen picker. Try again.") }
    }
    func refresh() {
        guard let filter else{return}
        generation+=1
        let token=generation
        let previous=stream;stream=nil;latest=nil;live=false;frozen=false
        Task { @MainActor [weak self] in
            if let previous {try? await previous.stopCapture()}
            guard let self,self.generation==token,self.filter != nil else{return}
            let config=SCStreamConfiguration()
            config.width=Int(self.dimensions.width);config.height=Int(self.dimensions.height)
            config.pixelFormat=kCVPixelFormatType_32BGRA
            config.minimumFrameInterval=CMTime(value:1,timescale:10)
            config.queueDepth=3;config.capturesAudio=false;config.showsCursor=false
            config.colorSpaceName=CGColorSpace.sRGB
            config.streamName=L10n.text("DuoFlip desktop effect (processed locally)")
            if #available(macOS 15.0,*) {config.captureMicrophone=false}
            let created=SCStream(filter:filter,configuration:config,delegate:self)
            do {
                try created.addStreamOutput(self,type:.screen,sampleHandlerQueue:self.framesQueue)
                self.stream=created;self.receivedAt=ProcessInfo.processInfo.systemUptime
                try await created.startCapture()
                guard self.generation==token else {try? await created.stopCapture();return}
                self.live=true;self.onReady?()
            } catch {
                guard self.generation==token else{return}
                self.stop();self.onFailure?("Capture failed or was interrupted · Effect turned off")
            }
        }
    }
    func freeze(using context:CIContext)->CIImage? {
        guard live,let latest else{return nil}
        // Deep-copy once so the capture pool cannot reuse the frozen IOSurface.
        let source=CIImage(cvPixelBuffer:latest)
        guard let cg=context.createCGImage(source,from:source.extent) else{return nil}
        frozen=true;self.latest=nil
        return CIImage(cgImage:cg)
    }
    func pause() {
        generation+=1;latest=nil;frozen=false;live=false
        let old=stream;stream=nil
        if let old {Task {try? await old.stopCapture()}}
    }
    func stop() {
        selecting=false;filter=nil;displayID=nil;pause()
        SCContentSharingPicker.shared.isActive=false
    }
    func stream(_ stream:SCStream,didStopWithError error:Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self,self.stream === stream else{return}
            self.stop();self.onFailure?("Screen capture interrupted · Effect turned off")
        }
    }
    func stream(_ stream:SCStream,didOutputSampleBuffer sampleBuffer:CMSampleBuffer,of outputType:SCStreamOutputType) {
        guard outputType == .screen,sampleBuffer.isValid,
              let attachments=CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],
              let rawStatus=attachments.first?[.status] as? Int,
              let status=SCFrameStatus(rawValue:rawStatus) else{return}
        let pixel=CMSampleBufferGetImageBuffer(sampleBuffer)
        let now=ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.async { [weak self] in
            guard let self,self.stream === stream else{return}
            if status == .blank || status == .suspended || status == .stopped {
                self.latest=nil;self.onEvent?("desktop-content-unavailable");return
            }
            if status == .idle {self.receivedAt=now;return}
            guard status == .complete,let pixel else{return}
            self.receivedAt=now
            guard !self.frozen else{return}
            self.latest=pixel;self.frameCount+=1
        }
    }
}
