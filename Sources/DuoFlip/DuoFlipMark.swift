import AppKit

// Shared vector geometry for the menu-bar template and the app's brand artwork.
// Coordinates use an 18 pt square, with the origin at the top left.
enum DuoFlipMark {
    static let outline:[(String,[CGFloat])] = [
        ("M",[9,5]),("L",[3.9,2.2]),
        ("C",[3.1,1.75,2.5,2.15,2.5,3.15]),("L",[2.5,11.4]),
        ("C",[2.5,12,2.75,12.45,3.3,12.75]),("L",[9,15.9]),
        ("L",[14.7,12.75]),("C",[15.25,12.45,15.5,12,15.5,11.4]),
        ("L",[15.5,3.15]),("C",[15.5,2.15,14.9,1.75,14.1,2.2]),("Z",[])
    ]
    static func draw(in rect:NSRect,color:NSColor) {
        NSGraphicsContext.saveGraphicsState()
        let transform=NSAffineTransform()
        transform.translateX(by:rect.minX,yBy:rect.minY)
        transform.scaleX(by:rect.width/18,yBy:rect.height/18)
        transform.concat()
        let path=NSBezierPath()
        for (command,p) in outline {
            switch command {
            case "M":path.move(to:NSPoint(x:p[0],y:p[1]))
            case "L":path.line(to:NSPoint(x:p[0],y:p[1]))
            case "C":path.curve(to:NSPoint(x:p[4],y:p[5]),controlPoint1:NSPoint(x:p[0],y:p[1]),controlPoint2:NSPoint(x:p[2],y:p[3]))
            default:path.close()
            }
        }
        path.move(to:NSPoint(x:9,y:5));path.line(to:NSPoint(x:9,y:15.9))
        path.lineWidth=1.5;path.lineJoinStyle = .round;path.lineCapStyle = .round
        color.setStroke();path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    static func menuImage(enabled:Bool)->NSImage {
        let image=NSImage(size:NSSize(width:23,height:18),flipped:true) { rect in
            draw(in:NSRect(x:0,y:0,width:18,height:18),color:.black)
            if enabled {
                NSColor.black.setFill()
                NSBezierPath(ovalIn:NSRect(x:19.25,y:11.75,width:2.5,height:2.5)).fill()
            }
            return true
        }
        image.isTemplate=true
        image.accessibilityDescription="DuoFlip"
        return image
    }
    static var svg:String {
        let commands=outline.map { command,values in command+values.map{String(format:"%g",Double($0))}.joined(separator:" ") }.joined(separator:" ")
        return """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18" fill="none">
          <title>DuoFlip</title>
          <path d="\(commands) M9 5 L9 15.9" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        """
    }
}
