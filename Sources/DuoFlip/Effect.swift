import AppKit
import CoreImage
import MetalKit

struct MotionState {
    private(set) var angle: Double?
    private var lastTime: TimeInterval?
    let startAngle = 90.0
    let endAngle = 20.0
    mutating func reset() { angle = nil; lastTime = nil }
    mutating func accept(_ raw: Double, at time: TimeInterval) {
        guard raw.isFinite, (0...180).contains(raw) else { reset(); return }
        if let old = angle, let previous = lastTime, time > previous, time-previous < 0.5 {
            let alpha = 1-exp(-(time-previous)/0.045)
            angle = old+(raw-old)*alpha
        } else { angle = raw }
        lastTime = time
    }
    func progress(for override: Double? = nil) -> Double {
        guard let a = override ?? angle else { return 0 }
        let t = min(1,max(0,(startAngle-a)/(startAngle-endAngle)))
        return t*t*(3-2*t)
    }
}

// Two continuous-time filters preserve velocity across discrete sensor readings.
// Their analytic response is independent of the display refresh rate.
struct EffectMotion {
    private(set) var value = 0.0
    private var intermediate = 0.0
    var target = 0.0
    var settled: Bool { abs(value-target)<0.00001 && abs(intermediate-target)<0.00001 }
    mutating func advance(_ dt:Double) {
        guard dt.isFinite,dt>0 else{return}
        let t=min(dt,0.05), omega=80.0, decay=exp(-omega*t)
        let previous=intermediate
        intermediate=target+(previous-target)*decay
        value=target+((value-target)+omega*t*(previous-target))*decay
        if settled {value=target;intermediate=target}
    }
}

final class EffectRenderer {
    let context: CIContext
    let source: CIImage
    init(device: MTLDevice, sourceURL: URL? = nil) {
        context = CIContext(mtlDevice:device, options:[.cacheIntermediates:false])
        guard let sourceURL,let full=CIImage(contentsOf:sourceURL) else {
            source=CIImage(color:.black).cropped(to:CGRect(x:0,y:0,width:1600,height:1000))
            return
        }
        let crop = CGRect(x:148,y:154,width:874,height:610)
        source = full.cropped(to:crop).transformed(by:CGAffineTransform(translationX:-crop.minX,y:-crop.minY))
    }
    func image(size: CGSize, progress: Double, strength: Double, overrideSource: CIImage? = nil) -> CIImage {
        let w=size.width, h=size.height
        let p=min(1,max(0,progress*strength))
        let source=overrideSource ?? self.source
        let scale=overrideSource == nil ? max(w/source.extent.width,h/source.extent.height) : min(w/source.extent.width,h/source.extent.height)
        var image=source.transformed(by:CGAffineTransform(scaleX:scale,y:scale))
        image=image.transformed(by:CGAffineTransform(translationX:(w-image.extent.width)/2,y:overrideSource == nil ? h-image.extent.height : (h-image.extent.height)/2))
        let rect=CGRect(origin:.zero,size:size)
        image=image.cropped(to:rect)
        if p > 0 {
            image=image.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:p*16*w/1600]).cropped(to:rect)
            // Keep geometry planar: top narrows, base stays at the hinge side.
            image=image.applyingFilter("CIPerspectiveTransform",parameters:[
                "inputTopLeft":CIVector(x:w*0.29*p,y:h),
                "inputTopRight":CIVector(x:w*(1-0.29*p),y:h),
                "inputBottomLeft":CIVector(x:0,y:0),
                "inputBottomRight":CIVector(x:w,y:0)])
            let light=1-0.70*p
            image=image.applyingFilter("CIColorMatrix",parameters:[
                "inputRVector":CIVector(x:light,y:0,z:0,w:0),
                "inputGVector":CIVector(x:0,y:light,z:0,w:0),
                "inputBVector":CIVector(x:0,y:0,z:light,w:0)])
        }
        return image.composited(over:CIImage(color:.black).cropped(to:rect)).cropped(to:rect)
    }
}

final class EffectView: MTKView, MTKViewDelegate {
    let renderer: EffectRenderer
    let commands: MTLCommandQueue
    private var motion=EffectMotion()
    private var lastFrame:TimeInterval?
    private var revision=0
    private(set) var waitingForFirstFrame=false
    private var firstFrameSubmitted=false
    private var presentationGeneration=0
    var onFirstPresented:(()->Void)?
    var onSettled:(()->Void)?
    var onRendered: ((Double)->Void)?
    var overrideSource: CIImage? { didSet { needsDisplay=true } }
    init(renderer:EffectRenderer,device:MTLDevice) {
        self.renderer=renderer
        commands=device.makeCommandQueue()!
        super.init(frame:.zero,device:device)
        colorPixelFormat = .bgra8Unorm
        framebufferOnly=false
        isPaused=true
        enableSetNeedsDisplay=true
        preferredFramesPerSecond=60
        clearColor=MTLClearColorMake(0,0,0,1)
        delegate=self
        setAccessibilityElement(true)
        setAccessibilityLabel("随翻盖角度变化的测试画面")
    }
    required init(coder:NSCoder) { fatalError("not used") }
    // Keep the snapshot underneath visible until the drawable is presented, not
    // merely submitted or GPU-complete. Start easing from clear at that boundary.
    func prepareFirstFrame() {
        presentationGeneration+=1
        waitingForFirstFrame=true;firstFrameSubmitted=false
        wantsLayer=true
        CATransaction.begin();CATransaction.setDisableActions(true)
        layer?.opacity=0
        CATransaction.commit()
        needsDisplay=true
    }
    func set(progress:Double,strength:Double) {
        let target=min(1,max(0,progress*strength))
        guard target != motion.target else { return }
        motion.target=target;revision+=1
        if waitingForFirstFrame {return}
        if isPaused {lastFrame=ProcessInfo.processInfo.systemUptime}
        isPaused=false
    }
    func stopAnimating() {
        presentationGeneration+=1;waitingForFirstFrame=false
        isPaused=true;onSettled=nil;onFirstPresented=nil
    }
    func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) { needsDisplay=true }
    func draw(in view:MTKView) {
        if waitingForFirstFrame && firstFrameSubmitted {return}
        guard drawableSize.width>0, drawableSize.height>0,let drawable=currentDrawable,let command=commands.makeCommandBuffer() else { return }
        let start=ProcessInfo.processInfo.systemUptime
        if !waitingForFirstFrame {motion.advance(start-(lastFrame ?? start))}
        lastFrame=start
        let image=renderer.image(size:drawableSize,progress:motion.value,strength:1,overrideSource:overrideSource)
        renderer.context.render(image,to:drawable.texture,commandBuffer:command,bounds:CGRect(origin:.zero,size:drawableSize),colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
        if waitingForFirstFrame {
            firstFrameSubmitted=true;isPaused=true
            let generation=presentationGeneration
            drawable.addPresentedHandler { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self,self.waitingForFirstFrame,self.presentationGeneration==generation else{return}
                    self.waitingForFirstFrame=false
                    CATransaction.begin();CATransaction.setDisableActions(true)
                    self.layer?.opacity=1
                    CATransaction.commit()
                    self.lastFrame=ProcessInfo.processInfo.systemUptime
                    self.isPaused=false
                    let completion=self.onFirstPresented;self.onFirstPresented=nil;completion?()
                }
            }
        }
        command.present(drawable)
        let settled=motion.settled, submittedRevision=revision
        if settled {isPaused=true;lastFrame=nil}
        command.addCompletedHandler { [weak self] _ in
            let elapsed=(ProcessInfo.processInfo.systemUptime-start)*1000
            DispatchQueue.main.async {
                guard let self else{return}
                self.onRendered?(elapsed)
                if settled,self.revision == submittedRevision {
                    let completion=self.onSettled;self.onSettled=nil;completion?()
                }
            }
        }
        command.commit()
    }
}

// The CPU-backed snapshot is installed before the window is ordered onscreen.
// Metal's initially empty drawable can therefore never cover it with black.
final class SnapshotEffectSurface:NSView {
    let effect:EffectView
    init(frame:NSRect,snapshot:CGImage,renderer:EffectRenderer,device:MTLDevice) {
        effect=EffectView(renderer:renderer,device:device)
        super.init(frame:frame)
        wantsLayer=true
        layer?.backgroundColor=NSColor.black.cgColor
        layer?.contents=snapshot
        layer?.contentsGravity = .resizeAspect
        effect.frame=bounds;effect.autoresizingMask=[.width,.height]
        effect.overrideSource=CIImage(cgImage:snapshot)
        addSubview(effect)
        effect.prepareFirstFrame()
    }
    required init?(coder:NSCoder) {fatalError("not used")}
}
