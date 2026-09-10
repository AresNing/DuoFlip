import Foundation
import IOKit.hid

struct LidSample {
    let angle: Double
    let readMilliseconds: Double
    let timestamp: TimeInterval
}

enum LidError: Error, CustomStringConvertible {
    case notFound, open(Int32), report(Int32), malformed
    var description: String {
        switch self {
        case .notFound: return "未找到翻盖角度传感器"
        case .open(let code): return "传感器打开失败：\(code)"
        case .report(let code): return "传感器读取失败：\(code)"
        case .malformed: return "传感器返回了无效角度"
        }
    }
}

// Protocol reference: samhenrigold/LidAngleSensor. Dedicated orientation HID only;
// no keyboard enumeration, event taps, device writes or exclusive acquisition.
final class LidSensor {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    func connect() throws {
        disconnect()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x05ac, kIOHIDPrimaryUsagePageKey: 0x20, kIOHIDPrimaryUsageKey: 0x8a] as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, let found = devices.first else { throw LidError.notFound }
        let result = IOHIDDeviceOpen(found, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else { throw LidError.open(result) }
        self.manager = manager
        device = found
    }
    func read() throws -> LidSample {
        guard let device else { throw LidError.notFound }
        var bytes = [UInt8](repeating: 0, count: 8)
        var length = CFIndex(bytes.count)
        let before = ProcessInfo.processInfo.systemUptime
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &bytes, &length)
        let after = ProcessInfo.processInfo.systemUptime
        guard result == kIOReturnSuccess else { throw LidError.report(result) }
        guard length >= 3, bytes[0] == 1 else { throw LidError.malformed }
        let angle = Double(UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        guard (0...180).contains(angle) else { throw LidError.malformed }
        return LidSample(angle: angle, readMilliseconds: (after-before)*1000, timestamp: after)
    }
    func disconnect() {
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        manager = nil
    }
    deinit { disconnect() }
}
