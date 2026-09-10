import AppKit
import AVFoundation
import ImageIO
import MetalKit
import UniformTypeIdentifiers

// Documentation-only: generated artwork and simulated angles, using production
// effect/policy code. No sensor, screen capture, audio, or network access.
@main struct RenderDemo {
    static let width = 1280, height = 800, fps = 30, count = 360
    static let ink = NSColor(calibratedWhite: 0.94, alpha: 1)
    static let muted = NSColor(calibratedWhite: 0.58, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.5, green: 0.86, blue: 0.97, alpha: 1)

    static func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
                     _ color: NSColor = ink, weight: NSFont.Weight = .regular) {
        (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
        ])
    }
    static func box(_ rect: CGRect, _ color: NSColor, radius: CGFloat = 16) {
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }
    static func bitmap(_ w: Int, _ h: Int, draw: () -> Void) -> CGImage {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage!
    }
    static func desktop() -> CGImage {
        bitmap(900, 562) {
            NSGradient(colors: [NSColor(calibratedRed: 0.14, green: 0.24, blue: 0.36, alpha: 1),
                                NSColor(calibratedRed: 0.44, green: 0.58, blue: 0.62, alpha: 1)])!
                .draw(in: CGRect(x: 0, y: 0, width: 900, height: 562), angle: 35)
            NSColor(calibratedRed: 0.61, green: 0.76, blue: 0.74, alpha: 0.3).setFill()
            NSBezierPath(ovalIn: CGRect(x: 430, y: -150, width: 650, height: 650)).fill()
            box(CGRect(x: 0, y: 534, width: 900, height: 28), NSColor(white: 0.05, alpha: 0.35), radius: 0)
            text("DuoFlip     文件     编辑     视图", 20, 541, 12)
            text("09:41", 843, 541, 12)
            box(CGRect(x: 88, y: 99, width: 690, height: 373), NSColor(white: 0.94, alpha: 1), radius: 14)
            box(CGRect(x: 88, y: 99, width: 160, height: 373), NSColor(calibratedRed: 0.85, green: 0.89, blue: 0.89, alpha: 1), radius: 14)
            for (i, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                color.setFill(); NSBezierPath(ovalIn: CGRect(x: 105+i*19, y: 446, width: 10, height: 10)).fill()
            }
            text("笔记", 110, 391, 16, .darkGray, weight: .semibold)
            box(CGRect(x: 101, y: 348, width: 133, height: 32), NSColor(white: 1, alpha: 0.6), radius: 7)
            text("今天的想法", 113, 356, 13, .darkGray)
            text("灵感收藏", 113, 313, 13, .darkGray)
            text("稍后阅读", 113, 271, 13, .darkGray)
            text("留一点空间", 280, 363, 39, NSColor(white: 0.14, alpha: 1), weight: .semibold)
            text("给下一个想法。", 280, 308, 39, NSColor(white: 0.14, alpha: 1), weight: .semibold)
            text("打开思路，让灵感自然发生。", 282, 258, 18, .darkGray)
            for (i, length) in [354, 306, 330].enumerated() {
                box(CGRect(x: 283, y: 214-i*23, width: length, height: 6), NSColor(white: 0.76, alpha: 1), radius: 3)
            }
            box(CGRect(x: 326, y: 22, width: 248, height: 54), NSColor(white: 1, alpha: 0.24), radius: 16)
            for i in 0..<5 {
                box(CGRect(x: 339+i*46, y: 32, width: 34, height: 34),
                    [NSColor.systemTeal, .systemOrange, .systemBlue, .systemGreen, .systemIndigo][i], radius: 9)
            }
        }
    }
    static func angle(at t: Double) -> Double {
        func ease(_ t: Double) -> Double { let v = min(1, max(0, t)); return v*v*(3-2*v) }
        if t < 1.4 { return 112 }
        if t < 5.2 { return 112-87*ease((t-1.4)/3.8) }
        if t < 6.4 { return 25 }
        if t < 10.2 { return 25+87*ease((t-6.4)/3.8) }
        return 112
    }
    static func frame(_ image: CGImage, angle: Double, t: Double) -> CGImage {
        bitmap(width, height) {
            box(CGRect(x: 0, y: 0, width: width, height: height), NSColor(calibratedRed: 0.055, green: 0.07, blue: 0.09, alpha: 1), radius: 0)
            DuoFlipMark.draw(in: CGRect(x: 52, y: 701, width: 44, height: 44), color: accent)
            text("DuoFlip", 115, 701, 42, weight: .semibold)
            text("随屏幕开合，自然过渡。", 55, 659, 23, muted)
            box(CGRect(x: 39, y: 123, width: 926, height: 508), NSColor(white: 0.18, alpha: 1), radius: 18)
            box(CGRect(x: 42, y: 126, width: 920, height: 502), .black, radius: 15)
            NSGraphicsContext.current!.cgContext.draw(image, in: CGRect(x: 52, y: 137, width: 900, height: 480))
            box(CGRect(x: 367, y: 607, width: 270, height: 12), .black, radius: 5)
            box(CGRect(x: 23, y: 114, width: 958, height: 13), NSColor(white: 0.47, alpha: 1), radius: 6)
            text("屏幕角度", 1026, 582, 18, muted)
            text("\(Int(angle.rounded()))°", 1020, 499, 64, weight: .light)
            let phase = t < 1.4 || t >= 10.2 ? "正常展开" : (t < 5.2 ? "缓缓合拢" : (t < 6.4 ? "保持角度" : "重新展开"))
            text(phase, 1026, 455, 21, accent)
            let hinge = CGPoint(x: 1072, y: 280)
            let radians = angle * .pi / 180
            let line = NSBezierPath(); line.lineWidth = 7; line.lineCapStyle = .round
            muted.setStroke(); line.move(to: hinge); line.line(to: CGPoint(x: 1200, y: 280)); line.stroke()
            let lid = NSBezierPath(); lid.lineWidth = 7; lid.lineCapStyle = .round
            accent.setStroke(); lid.move(to: hinge)
            lid.line(to: CGPoint(x: hinge.x+128*cos(radians), y: hinge.y+128*sin(radians))); lid.stroke()
            text("模糊 · 透视 · 明暗", 1026, 191, 16, muted)
            text("合拢时渐变，展开时还原", 55, 62, 20)
            text("生成桌面 · 模拟角度 · 原生动效渲染", 804, 64, 15, muted)
        }
    }
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = URL(fileURLWithPath: ".build/demo")
        let videoURL = directory.appendingPathComponent("duoflip-demo.mp4")
        let gifURL = directory.appendingPathComponent("duoflip-demo.gif")
        for url in [videoURL, gifURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let device = MTLCreateSystemDefaultDevice()!
        let renderer = EffectRenderer(device: device)
        let source = CIImage(cgImage: desktop())
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000,
                                             AVVideoMaxKeyFrameIntervalKey: fps,
                                             AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        writer.add(input); writer.shouldOptimizeForNetworkUse = true
        guard writer.startWriting() else { throw writer.error! }
        writer.startSession(atSourceTime: .zero)
        let gif = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, count/2, nil)!
        CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        var state = MotionState(), motion = EffectMotion(), policy = DesktopPolicy()
        policy.enable()
        for i in 0..<count {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            try autoreleasepool {
                let t = Double(i)/Double(fps), physicalAngle = angle(at: t)
                state.accept(physicalAngle.rounded(), at: t)
                _ = policy.update(angle: state.angle, progress: state.progress(), strength: 1, frameReady: true)
                motion.target = policy.visible ? state.progress() : 0
                motion.advance(1/60); motion.advance(1/60)
                let rendered = renderer.image(size: CGSize(width: 900, height: 562), progress: motion.value, strength: 1, overrideSource: source)
                let screen = renderer.context.createCGImage(rendered, from: rendered.extent)!
                let result = frame(screen, angle: physicalAngle, t: t)
                var pixel: CVPixelBuffer?
                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
                let buffer = pixel!
                CVPixelBufferLockBaseAddress(buffer, [])
                let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
                ctx.draw(result, in: CGRect(x: 0, y: 0, width: width, height: height))
                CVPixelBufferUnlockBaseAddress(buffer, [])
                guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(i), timescale: Int32(fps))) else { throw writer.error! }
                if i % 2 == 0 {
                    let small = bitmap(768, 480) {
                        NSGraphicsContext.current!.imageInterpolation = .high
                        NSGraphicsContext.current!.cgContext.draw(result, in: CGRect(x: 0, y: 0, width: 768, height: 480))
                    }
                    let delay = (i/2)%3 == 0 ? 0.06 : 0.07
                    CGImageDestinationAddImage(gif, small, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
                }
                if [0, 90, 165, 240, 359].contains(i) {
                    let url = URL(fileURLWithPath: ".build/demo/frame-\(i).png")
                    let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
                    CGImageDestinationAddImage(output, result, nil); precondition(CGImageDestinationFinalize(output))
                }
            }
        }
        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }; semaphore.wait()
        guard writer.status == .completed else { throw writer.error! }
        precondition(CGImageDestinationFinalize(gif))
        for source in [videoURL, gifURL] {
            let target = destination.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
            try FileManager.default.copyItem(at: source, to: target)
        }
        print("Generated 12-second H.264 video (1280×800, 30 fps) and looping GIF (768×480, 15 fps); no audio or capture")
    }
}
