import AppKit
import Carbon

// Register only while the effect is enabled. No keyboard event tap, key logging,
// Input Monitoring or Accessibility permission is needed for this hotkey.
final class EscapeShortcut {
    private var handler:EventHandlerRef?
    private var hotKey:EventHotKeyRef?
    var onEscape:(()->Void)?
    var isRegistered:Bool {hotKey != nil}
    init() {
        var type=EventTypeSpec(eventClass:OSType(kEventClassKeyboard),eventKind:UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),{_,event,context in
            guard let event,let context else{return OSStatus(eventNotHandledErr)}
            var identifier=EventHotKeyID()
            let result=GetEventParameter(event,EventParamName(kEventParamDirectObject),EventParamType(typeEventHotKeyID),nil,MemoryLayout<EventHotKeyID>.size,nil,&identifier)
            guard result==noErr,identifier.signature==0x4C696445,identifier.id==1 else{return OSStatus(eventNotHandledErr)}
            let shortcut=Unmanaged<EscapeShortcut>.fromOpaque(context).takeUnretainedValue()
            shortcut.onEscape?()
            return noErr
        },1,&type,Unmanaged.passUnretained(self).toOpaque(),&handler)
    }
    @discardableResult func setEnabled(_ enabled:Bool)->Bool {
        if !enabled {
            if let hotKey {UnregisterEventHotKey(hotKey)}
            hotKey=nil;return true
        }
        if hotKey != nil {return true}
        guard handler != nil else{return false}
        var identifier=EventHotKeyID(signature:0x4C696445,id:1)
        return RegisterEventHotKey(UInt32(kVK_Escape),0,identifier,GetApplicationEventTarget(),OptionBits(kEventHotKeyNoOptions),&hotKey)==noErr
    }
    deinit {
        setEnabled(false)
        if let handler {RemoveEventHandler(handler)}
    }
}
