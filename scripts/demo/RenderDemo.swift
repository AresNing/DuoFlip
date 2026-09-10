import AppKit
import AVFoundation
import ImageIO
import MetalKit
import UniformTypeIdentifiers

// Documentation-only: generated artwork and simulated angles, using production
// effect/policy code. No sensor, screen capture, audio, or network access.
@main struct RenderDemo {
    static let language = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "en"
    static let english:[String:String] = [
        "笔记":"Notes",
        "文件     编辑     格式     显示     窗口     帮助":"File    Edit    Format    View    Window    Help",
        "周四  9:41":"Thu  9:41",
        "海岸":"Coast",
        "晴朗":"Sunny",
        "最高 24°  最低 18°":"H:24°  L:18°",
        "星期四":"Thursday",
        "留出一点时间":"Take a moment",
        "整理新的灵感":"Find a little clarity",
        "今天，没有安排":"No events today",
        "文件夹":"Folders",
        "所有笔记":"All Notes",
        "旅途随记":"Travel Notes",
        "灵感片段":"Ideas",
        "最近删除":"Recently Deleted",
        "9月10日  09:41":"September 10  09:41",
        "山海之间":"Where land meets sea",
        "收集沿途的风景，也给新的想法留一点空白。":"Collect a few moments. Leave room for new ideas.",
        "下一次出发":"The next adventure",
        "挑一个晴天，沿着海岸散步":"Pick a sunny day for a walk along the coast",
        "带上相机，记录光线的变化":"Bring a camera. Follow the changing light.",
        "开合之间，自然流转。":"A natural transition.",
        "正常展开":"Fully open",
        "缓缓合拢":"Gently closing",
        "保持角度":"Holding",
        "重新展开":"Opening again",
        "生成桌面与模拟角度 · DuoFlip 原生动效渲染":"Illustrated desktop. Simulated angles. Native DuoFlip rendering."
    ]
    static func localized(_ text:String)->String {language == "en" ? (english[text] ?? text):text}
    static let width = 1600, height = 1200, fps = 30, count = 360
    // Exactly half the 14-inch MacBook Pro display resolution.
    static let desktopWidth = 1512, desktopHeight = 982
    static let screenRect = CGRect(x: 296, y: 270, width: 1008, height: 1964.0/3)
    static let ink = NSColor(calibratedWhite: 0.94, alpha: 1)
    static let muted = NSColor(calibratedWhite: 0.58, alpha: 1)
    static let accent = NSColor(calibratedRed: 0.5, green: 0.86, blue: 0.97, alpha: 1)

    static func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat,
                     _ color: NSColor = ink, weight: NSFont.Weight = .regular) {
        (localized(value) as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [
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
    static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    static func symbol(_ name: String, _ rect: CGRect, _ color: NSColor) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        image.withSymbolConfiguration(config)?.draw(in: rect)
    }
    static func centerText(_ value: String, y: CGFloat, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular) {
        let value=localized(value)
        let font = NSFont.systemFont(ofSize: size, weight: weight)
        let measured = (value as NSString).size(withAttributes: [.font: font])
        text(value, (CGFloat(width)-measured.width)/2, y, size, color, weight: weight)
    }
    static func border(_ rect: CGRect, radius: CGFloat, color: NSColor, line: CGFloat = 1) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        path.lineWidth = line; color.setStroke(); path.stroke()
    }
    static func glass(_ rect: CGRect, fill: NSColor, radius: CGFloat = 25, shadow: Bool = true) {
        NSGraphicsContext.saveGraphicsState()
        if shadow {
            let shade = NSShadow(); shade.shadowColor = .black.withAlphaComponent(0.17)
            shade.shadowBlurRadius = 28; shade.shadowOffset = NSSize(width: 0, height: -10); shade.set()
        }
        box(rect, fill, radius: radius)
        NSGraphicsContext.restoreGraphicsState()
        border(rect.insetBy(dx: 0.5, dy: 0.5), radius: radius, color: .white.withAlphaComponent(0.48))
    }
    // Original vector wallpaper. No Apple photography, screenshots, or wallpaper assets.
    static func wallpaper(_ rect: CGRect, warm: Bool = false) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width/1512, y: rect.height/982)
        NSGradient(colors: warm ? [rgb(0.2,0.26,0.48),rgb(0.72,0.55,0.65),rgb(0.99,0.79,0.56)] :
                    [rgb(0.055,0.09,0.29),rgb(0.2,0.35,0.75),rgb(0.52,0.82,0.91)])!
            .draw(in: CGRect(x: 0,y: 0,width: 1512,height: 982), angle: 72)
        let ribbon = NSBezierPath()
        ribbon.move(to: CGPoint(x: -100,y: 600))
        ribbon.curve(to: CGPoint(x: 1612,y: 1010),controlPoint1: CGPoint(x: 500,y: 160),controlPoint2: CGPoint(x: 810,y: 800))
        ribbon.line(to: CGPoint(x: 1612,y: -100)); ribbon.line(to: CGPoint(x: -100,y: -100)); ribbon.close()
        NSGradient(colors: warm ? [rgb(0.1,0.23,0.34),rgb(0.4,0.5,0.6)] :
                    [rgb(0.19,0.1,0.52),rgb(0.31,0.36,0.82),rgb(0.55,0.85,0.96)])!.draw(in: ribbon,angle: 125)
        let foreground = NSBezierPath()
        foreground.move(to: CGPoint(x: -30,y: 0))
        foreground.curve(to: CGPoint(x: 1550,y: 730),controlPoint1: CGPoint(x: 380,y: 820),controlPoint2: CGPoint(x: 1020,y: -350))
        foreground.line(to: CGPoint(x: 1550,y: -30)); foreground.close()
        NSGradient(colors: warm ? [rgb(0.10,0.2,0.29),rgb(0.25,0.4,0.44)] :
                    [rgb(0.08,0.12,0.32),rgb(0.17,0.26,0.61),rgb(0.39,0.63,0.86)])!.draw(in: foreground,angle: 55)
        NSGraphicsContext.restoreGraphicsState()
    }
    static func desktop() -> CGImage {
        bitmap(desktopWidth, desktopHeight) {
            wallpaper(CGRect(x: 0,y: 0,width: desktopWidth,height: desktopHeight))
            box(CGRect(x: 0,y: 949,width: 1512,height: 33),.black.withAlphaComponent(0.16),radius: 0)
            DuoFlipMark.draw(in: CGRect(x: 24,y: 958,width: 17,height: 17),color: .white)
            text("笔记",59,957,15,.white,weight: .semibold)
            text("文件     编辑     格式     显示     窗口     帮助",114,957,14,.white)
            symbol("wifi",CGRect(x: 1283,y: 958,width: 20,height: 16),.white)
            symbol("battery.100percent",CGRect(x: 1320,y: 956,width: 28,height: 18),.white)
            text("周四  9:41",1370,957,14,.white)

            // Two restrained translucent desktop widgets.
            glass(CGRect(x: 62,y: 690,width: 282,height: 200),fill: rgb(0.19,0.36,0.63,0.70))
            text("海岸",85,846,19,.white,weight: .medium)
            text("21°",81,769,62,.white,weight: .light)
            symbol("sun.max.fill",CGRect(x: 263,y: 792,width: 48,height: 48),rgb(1,0.88,0.52))
            text("晴朗",85,740,15,.white)
            text("最高 24°  最低 18°",85,712,14,.white.withAlphaComponent(0.78))
            glass(CGRect(x: 62,y: 458,width: 282,height: 204),fill: .white.withAlphaComponent(0.85))
            text("星期四",84,621,15,rgb(0.76,0.24,0.24),weight: .medium)
            text("10",80,542,62,rgb(0.12,0.15,0.2),weight: .light)
            text("留出一点时间",173,570,15,rgb(0.17,0.22,0.3),weight: .medium)
            text("整理新的灵感",173,543,13,rgb(0.4,0.44,0.49))
            box(CGRect(x: 85,y: 492,width: 237,height: 1),.black.withAlphaComponent(0.08),radius: 0)
            text("今天，没有安排",85,469,13,rgb(0.43,0.47,0.52))

            let window = CGRect(x: 398,y: 182,width: 1017,height: 649)
            glass(window,fill: rgb(0.98,0.985,0.99,0.97),radius: 15)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: window,xRadius: 15,yRadius: 15).addClip()
            box(CGRect(x: 398,y: 182,width: 214,height: 649),rgb(0.88,0.91,0.95,0.9),radius: 0)
            box(CGRect(x: 612,y: 776,width: 803,height: 55),rgb(0.96,0.97,0.985),radius: 0)
            box(CGRect(x: 612,y: 182,width: 1,height: 649),.black.withAlphaComponent(0.08),radius: 0)
            NSGraphicsContext.restoreGraphicsState()
            for (i,c) in [rgb(1,0.38,0.36),rgb(1,0.75,0.28),rgb(0.26,0.79,0.38)].enumerated() {
                c.setFill();NSBezierPath(ovalIn: CGRect(x: 420+i*23,y: 798,width: 13,height: 13)).fill()
            }
            symbol("sidebar.left",CGRect(x: 563,y: 796,width: 24,height: 18),.gray)
            text("文件夹",423,750,13,rgb(0.43,0.47,0.52),weight: .semibold)
            for (i,label) in ["所有笔记","旅途随记","灵感片段","最近删除"].enumerated() {
                let y = CGFloat(700-i*49)
                if i==1 {box(CGRect(x: 411,y: y-9,width: 187,height: 37),rgb(0.74,0.8,0.89),radius: 7)}
                symbol(i==3 ? "trash" : "folder",CGRect(x: 425,y: y,width: 18,height: 17),rgb(0.34,0.40,0.49))
                text(label,456,y,15,rgb(0.19,0.24,0.31))
            }
            symbol("square.and.pencil",CGRect(x: 637,y: 792,width: 24,height: 24),.gray)
            text("旅途随记",688,794,17,rgb(0.29,0.33,0.38),weight: .medium)
            for (i,name) in ["checklist","textformat","square.and.arrow.up","magnifyingglass"].enumerated() {
                symbol(name,CGRect(x: 1201+i*48,y: 794,width: 21,height: 21),.gray)
            }
            text("9月10日  09:41",928,745,12,rgb(0.55,0.57,0.61))
            text("山海之间",661,672,38,rgb(0.13,0.17,0.23),weight: .bold)
            text("收集沿途的风景，也给新的想法留一点空白。",663,632,19,rgb(0.39,0.43,0.49))
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: CGRect(x: 663,y: 364,width: 694,height: 237),xRadius: 10,yRadius: 10).addClip()
            wallpaper(CGRect(x: 663,y: 364,width: 694,height: 237),warm: true)
            NSGraphicsContext.restoreGraphicsState()
            text("下一次出发",663,312,19,rgb(0.2,0.24,0.3),weight: .semibold)
            for (i,label) in ["挑一个晴天，沿着海岸散步","带上相机，记录光线的变化"].enumerated() {
                let y=CGFloat(275-i*32)
                symbol("circle",CGRect(x: 665,y: y,width: 16,height: 16),rgb(0.71,0.57,0.3))
                text(label,691,y,16,rgb(0.42,0.46,0.52))
            }
            // Recognizable, individually detailed icons rather than flat color blocks.
            let dock = CGRect(x: 403,y: 26,width: 706,height: 90)
            glass(dock,fill: .white.withAlphaComponent(0.28),radius: 26)
            let symbols=["face.smiling","safari","envelope.fill","calendar","note.text","photo.on.rectangle","music.note","gearshape.fill","trash"]
            let colors=[rgb(0.19,0.62,0.96),rgb(0.11,0.56,0.91),rgb(0.13,0.58,0.94),rgb(0.96,0.28,0.3),rgb(0.94,0.72,0.2),rgb(0.53,0.44,0.86),rgb(0.92,0.24,0.4),rgb(0.47,0.52,0.6),rgb(0.70,0.76,0.81)]
            for i in 0..<9 {
                let x=CGFloat(420+i*76)
                let icon=CGRect(x: x,y: 41,width: 60,height: 60)
                let path=NSBezierPath(roundedRect: icon,xRadius: 14,yRadius: 14)
                NSGradient(starting: colors[i].blended(withFraction: 0.28,of: .white)!,ending: colors[i])!.draw(in: path,angle: 90)
                border(icon.insetBy(dx: 0.5,dy: 0.5),radius: 14,color: .white.withAlphaComponent(0.55))
                if i == 0 {
                    NSGraphicsContext.saveGraphicsState(); path.addClip()
                    box(CGRect(x: x+30,y: 41,width: 30,height: 60),rgb(0.81,0.92,1),radius: 0)
                    let face=rgb(0.09,0.28,0.49)
                    box(CGRect(x: x+16,y: 75,width: 3,height: 7),face,radius: 1.5)
                    box(CGRect(x: x+42,y: 75,width: 3,height: 7),face,radius: 1.5)
                    let smile=NSBezierPath(); smile.lineWidth=1.8; face.setStroke()
                    smile.move(to: CGPoint(x: x+14,y: 62))
                    smile.curve(to: CGPoint(x: x+46,y: 62),controlPoint1: CGPoint(x: x+22,y: 52),controlPoint2: CGPoint(x: x+38,y: 52)); smile.stroke()
                    NSGraphicsContext.restoreGraphicsState()
                } else if i == 3 {
                    box(icon.insetBy(dx: 2,dy: 2),.white,radius: 12)
                    text("THU",x+15,79,10,rgb(0.86,0.18,0.22),weight: .bold)
                    text("10",x+13,47,28,rgb(0.15,0.16,0.18),weight: .light)
                } else {
                    symbol(symbols[i],CGRect(x: x+12,y: 53,width: 36,height: 36),.white)
                }
                if [0,1,4].contains(i) {box(CGRect(x: x+28,y: 32,width: 4,height: 4),.white.withAlphaComponent(0.75),radius: 2)}
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
            let dark=rgb(0.10,0.11,0.13), secondary=rgb(0.48,0.49,0.52)
            box(CGRect(x: 0,y: 0,width: width,height: height),rgb(0.965,0.967,0.976),radius: 0)
            DuoFlipMark.draw(in: CGRect(x: 697,y: 1117,width: 27,height: 27),color: dark)
            text("DuoFlip",737,1109,34,dark,weight: .semibold)
            centerText("开合之间，自然流转。",y: 1032,size: 49,color: dark,weight: .semibold)

            // Soft studio contact shadow, machined rim and front-on screen.
            NSGraphicsContext.saveGraphicsState()
            let shadow=NSShadow();shadow.shadowColor = .black.withAlphaComponent(0.23)
            shadow.shadowBlurRadius=30;shadow.shadowOffset=NSSize(width: 0,height: -9);shadow.set()
            box(CGRect(x: 265,y: 208,width: 1070,height: 20),rgb(0.25,0.26,0.28),radius: 13)
            NSGraphicsContext.restoreGraphicsState()
            let lid=CGRect(x: 283,y: 250,width: 1034,height: 688)
            let lidPath=NSBezierPath(roundedRect: lid,xRadius: 22,yRadius: 22)
            NSGradient(colors: [rgb(0.17,0.18,0.20),rgb(0.44,0.45,0.47),rgb(0.12,0.13,0.15)])!.draw(in: lidPath,angle: 22)
            box(lid.insetBy(dx: 2,dy: 2),rgb(0.025,0.028,0.033),radius: 20)
            border(lid.insetBy(dx: 1,dy: 1),radius: 21,color: .white.withAlphaComponent(0.19),line: 1)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: screenRect,xRadius: 12,yRadius: 12).addClip()
            NSGraphicsContext.current!.cgContext.draw(image,in: screenRect)
            NSGraphicsContext.restoreGraphicsState()
            // Notch is about 11% of screen width, not the previous 30%.
            let notch=CGRect(x: 744,y: screenRect.maxY-19,width: 112,height: 20)
            box(notch,rgb(0.025,0.028,0.033),radius: 6)
            box(CGRect(x: 797.8,y: screenRect.maxY-10,width: 4.4,height: 4.4),rgb(0.13,0.17,0.22),radius: 2.2)
            box(CGRect(x: 785,y: 254,width: 30,height: 2),.white.withAlphaComponent(0.04),radius: 1)

            let deck=NSBezierPath()
            deck.move(to: CGPoint(x: 283,y: 252));deck.line(to: CGPoint(x: 1317,y: 252))
            deck.line(to: CGPoint(x: 1360,y: 214));deck.line(to: CGPoint(x: 240,y: 214));deck.close()
            NSGradient(colors: [rgb(0.29,0.3,0.32),rgb(0.54,0.55,0.57),rgb(0.31,0.32,0.34)])!.draw(in: deck,angle: 90)
            // Shallow keyboard/deck detail matches a nearly frontal product view.
            for row in 0..<3 {
                for column in 0..<14 {
                    let keyX = CGFloat(420+column*54-row*2)
                    let keyY = CGFloat(239-row*5)
                    box(CGRect(x: keyX,y: keyY,width: 47,height: 3.5),rgb(0.08,0.09,0.10),radius: 1)
                }
            }
            border(CGRect(x: 682,y: 216,width: 236,height: 11),radius: 3,color: .black.withAlphaComponent(0.16),line: 0.6)
            let front=NSBezierPath(roundedRect: CGRect(x: 240,y: 201,width: 1120,height: 15),xRadius: 9,yRadius: 9)
            NSGradient(colors: [rgb(0.18,0.19,0.21),rgb(0.52,0.53,0.55),rgb(0.34,0.35,0.37)])!.draw(in: front,angle: 90)
            box(CGRect(x: 723,y: 208,width: 154,height: 7),rgb(0.26,0.27,0.29),radius: 4)
            box(CGRect(x: 263,y: 215,width: 1074,height: 1),.white.withAlphaComponent(0.25),radius: 0)

            let phase=t < 1.4 || t >= 10.2 ? "正常展开" : (t < 5.2 ? "缓缓合拢" : (t < 6.4 ? "保持角度" : "重新展开"))
            centerText("\(localized(phase))   ·   \(Int(angle.rounded()))°",y: 125,size: 23,color: secondary,weight: .medium)
            centerText("生成桌面与模拟角度 · DuoFlip 原生动效渲染",y: 52,size: 16,color: secondary)
        }
    }
    static func main() throws {
        precondition(abs(CGFloat(desktopWidth)/CGFloat(desktopHeight)-3024.0/1964)<0.000001)
        precondition(abs(screenRect.width/screenRect.height-CGFloat(desktopWidth)/CGFloat(desktopHeight))<0.000001,
                     "Desktop artwork must be displayed without stretching")
        precondition(["en","zh-Hans"].contains(language),"Language must be en or zh-Hans")
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        let directory = URL(fileURLWithPath: ".build/demo/"+language)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let basename=language == "en" ? "duoflip-demo.en":"duoflip-demo.zh-CN"
        let videoURL = directory.appendingPathComponent(basename+".mp4")
        let gifURL = directory.appendingPathComponent(basename+".gif")
        for url in [videoURL, gifURL] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let device = MTLCreateSystemDefaultDevice()!
        let renderer = EffectRenderer(device: device)
        let source = CIImage(cgImage: desktop())
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_500_000,
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
                let rendered = renderer.image(size: CGSize(width: desktopWidth, height: desktopHeight), progress: motion.value, strength: 1, overrideSource: source)
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
                    let small = bitmap(800, 600) {
                        NSGraphicsContext.current!.imageInterpolation = .high
                        NSGraphicsContext.current!.cgContext.draw(result, in: CGRect(x: 0, y: 0, width: 800, height: 600))
                    }
                    let delay = (i/2)%3 == 0 ? 0.06 : 0.07
                    CGImageDestinationAddImage(gif, small, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
                }
                if [0, 90, 165, 240, 359].contains(i) {
                    let url = directory.appendingPathComponent("frame-\(i).png")
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
        print("Generated 12-second H.264 video (1600×1200, 30 fps) and looping GIF (800×600, 15 fps); no audio or capture")
    }
}
