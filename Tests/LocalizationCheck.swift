import Foundation
@main struct LocalizationCheck {
    static func main() throws {
        let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
        let bundle=Bundle(url:root.appendingPathComponent("Resources"))!
        let enURL=root.appendingPathComponent("Resources/en.lproj/Localizable.strings")
        let zhURL=root.appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")
        func catalog(_ url:URL)throws->[String:String] {
            try PropertyListSerialization.propertyList(from:Data(contentsOf:url),format:nil) as! [String:String]
        }
        let en=try catalog(enURL),zh=try catalog(zhURL)
        precondition(Set(en.keys)==Set(zh.keys))
        for key in en.keys {
            precondition(!zh[key]!.isEmpty)
            precondition(key.components(separatedBy:"%@").count == zh[key]!.components(separatedBy:"%@").count)
            precondition(L10n.text(key,language:.chinese,bundle:bundle)==zh[key])
            precondition(L10n.text(key,language:.english,bundle:bundle)==key)
        }
        for preferred in [["zh-CN"],["zh-Hant-TW","en"],["fr-FR","zh_CN"]] {
            precondition(AppLanguage.resolve(.system,preferred:preferred) == .chinese)
        }
        for preferred in [["en-US","zh-CN"],["fr-FR","en-GB"],["ja-JP"],[]] {
            precondition(AppLanguage.resolve(.system,preferred:preferred) == .english)
        }
        precondition(AppLanguage.resolve(.english,preferred:["zh-CN"]) == .english)
        precondition(AppLanguage.resolve(.chinese,preferred:["en-US"]) == .chinese)
        let app=LocalizedMessage(key:"Feishu / Lark")
        let blocked:LocalizedMessage="\(app) is running · Effect turned off"
        precondition(blocked.rendered(language:.english,bundle:bundle)=="Feishu / Lark is running · Effect turned off")
        precondition(blocked.rendered(language:.chinese,bundle:bundle)=="飞书 / Lark 正在运行，已自动关闭效果")
        let error:LocalizedMessage="Could not read lid-angle sensor: \(-42)"
        let stopped:LocalizedMessage="\(error) · Effect is off"
        precondition(stopped.rendered(language:.chinese,bundle:bundle)=="传感器读取失败：-42 · 效果已关闭")
        precondition(stopped.rendered(language:.english,bundle:bundle)=="Could not read lid-angle sensor: -42 · Effect is off")
        precondition(L10n.text("Unknown message",language:.chinese,bundle:bundle)=="Unknown message")
        print("PASS: \(en.count) bilingual messages, placeholder parity, system language preference order, explicit overrides, fallback, and live re-rendering of nested statuses")
    }
}
