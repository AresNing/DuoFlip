import AppKit

@main struct RenderBrand {
    static func main() throws {
        let output=URL(fileURLWithPath:CommandLine.arguments[1])
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        try DuoFlipMark.svg.write(to:output.appendingPathComponent("DuoFlip-mark.svg"),atomically:true,encoding:.utf8)
        for scale in [1,2,3] {
            try png(size:NSSize(width:23,height:18),scale:scale,name:"DuoFlip-menubar-off@\(scale)x.png",output:output) { _ in
                DuoFlipMark.draw(in:NSRect(x:0,y:0,width:18,height:18),color:.black)
            }
            try png(size:NSSize(width:23,height:18),scale:scale,name:"DuoFlip-menubar-on@\(scale)x.png",output:output) { _ in
                DuoFlipMark.draw(in:NSRect(x:0,y:0,width:18,height:18),color:.black)
                NSColor.black.setFill();NSBezierPath(ovalIn:NSRect(x:19.25,y:11.75,width:2.5,height:2.5)).fill()
            }
        }
        try png(size:NSSize(width:1024,height:1024),scale:1,name:"AppIcon.png",output:output) { _ in
            let bg=NSBezierPath(roundedRect:NSRect(x:40,y:40,width:944,height:944),xRadius:205,yRadius:205)
            NSGradient(starting:NSColor(calibratedRed:0.09,green:0.15,blue:0.31,alpha:1),ending:NSColor(calibratedRed:0.03,green:0.06,blue:0.14,alpha:1))!.draw(in:bg,angle:90)
            DuoFlipMark.draw(in:NSRect(x:194,y:168,width:636,height:636),color:NSColor(calibratedRed:0.58,green:0.88,blue:1,alpha:1))
        }
        try png(size:NSSize(width:1120,height:720),scale:1,name:"DuoFlip-brand-preview.png",output:output) { _ in
            NSColor(calibratedRed:0.955,green:0.959,blue:0.970,alpha:1).setFill();NSRect(x:0,y:0,width:1120,height:720).fill()
            label("DuoFlip",at:NSPoint(x:56,y:42),font:.systemFont(ofSize:36,weight:.semibold),color:.black)
            label("两片屏幕 · 一条折叠中轴",at:NSPoint(x:58,y:93),font:.systemFont(ofSize:17),color:NSColor(calibratedWhite:0.42,alpha:1))
            card(NSRect(x:56,y:151,width:440,height:343),fill:.white)
            DuoFlipMark.draw(in:NSRect(x:166,y:190,width:220,height:220),color:NSColor(calibratedWhite:0.1,alpha:1))
            label("品牌图形",at:NSPoint(x:78,y:452),font:.systemFont(ofSize:15),color:NSColor(calibratedWhite:0.42,alpha:1))
            card(NSRect(x:520,y:151,width:544,height:154),fill:.white)
            label("浅色菜单栏",at:NSPoint(x:545,y:174),font:.systemFont(ofSize:14),color:NSColor(calibratedWhite:0.42,alpha:1))
            bar(x:545,y:215,dark:false,enabled:false)
            card(NSRect(x:520,y:329,width:544,height:165),fill:NSColor(calibratedWhite:0.11,alpha:1))
            label("深色菜单栏 · 效果开启",at:NSPoint(x:545,y:352),font:.systemFont(ofSize:14),color:NSColor(calibratedWhite:0.7,alpha:1))
            bar(x:545,y:394,dark:true,enabled:true)
            card(NSRect(x:56,y:518,width:1008,height:146),fill:.white)
            DuoFlipMark.draw(in:NSRect(x:84,y:554,width:58,height:58),color:.black)
            label("18 pt 单色模板",at:NSPoint(x:173,y:550),font:.systemFont(ofSize:19,weight:.medium),color:.black)
            label("自动适配系统明暗外观；小圆点表示效果开启。",at:NSPoint(x:173,y:589),font:.systemFont(ofSize:16),color:NSColor(calibratedWhite:0.42,alpha:1))
            label("单击图标打开原生 macOS 设置页。",at:NSPoint(x:173,y:618),font:.systemFont(ofSize:16),color:NSColor(calibratedWhite:0.42,alpha:1))
        }
        print("Rendered shared brand geometry and menu-bar assets")
    }
    static func png(size:NSSize,scale:Int,name:String,output:URL,draw:(NSRect)->Void)throws {
        let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(size.width)*scale,pixelsHigh:Int(size.height)*scale,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        rep.size=size
        let context=NSGraphicsContext(bitmapImageRep:rep)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:context.cgContext,flipped:true)
        let transform=NSAffineTransform();transform.translateX(by:0,yBy:size.height);transform.scaleX(by:1,yBy:-1);transform.concat()
        draw(NSRect(origin:.zero,size:size))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name))
    }
    static func label(_ text:String,at point:NSPoint,font:NSFont,color:NSColor) {
        (text as NSString).draw(at:point,withAttributes:[.font:font,.foregroundColor:color])
    }
    static func card(_ rect:NSRect,fill:NSColor) {fill.setFill();NSBezierPath(roundedRect:rect,xRadius:18,yRadius:18).fill()}
    static func bar(x:CGFloat,y:CGFloat,dark:Bool,enabled:Bool) {
        let ink=dark ? NSColor.white:NSColor.black
        // 3x visual enlargement of an 18 pt glyph alongside familiar menu items.
        let t=NSAffineTransform();NSGraphicsContext.saveGraphicsState();t.translateX(by:x,yBy:y);t.scaleX(by:2.5,yBy:2.5);t.concat()
        DuoFlipMark.draw(in:NSRect(x:0,y:0,width:18,height:18),color:ink)
        if enabled {ink.setFill();NSBezierPath(ovalIn:NSRect(x:19.25,y:11.75,width:2.5,height:2.5)).fill()}
        label("⋯       17:30",at:NSPoint(x:75,y:1),font:.systemFont(ofSize:13,weight:.medium),color:ink)
        NSGraphicsContext.restoreGraphicsState()
    }
}
