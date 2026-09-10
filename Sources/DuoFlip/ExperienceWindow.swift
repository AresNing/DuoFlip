import AppKit

final class ExperienceWindow:NSPanel {
    var onEscape:(()->Void)?
    override var canBecomeKey:Bool {true}
    override var canBecomeMain:Bool {!styleMask.contains(.nonactivatingPanel)}
    override func keyDown(with event:NSEvent) {
        if event.keyCode == 53 {onEscape?()} else {super.keyDown(with:event)}
    }
    override func cancelOperation(_ sender:Any?) {onEscape?()}
}
