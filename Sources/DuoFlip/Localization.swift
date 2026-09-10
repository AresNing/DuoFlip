import Foundation

enum AppLanguage:String,CaseIterable,Identifiable {
    case system,english="en",chinese="zh-Hans"
    var id:String {rawValue}
    var title:String {
        switch self {
        case .system:return L10n.text("System")
        case .english:return "English"
        case .chinese:return "简体中文"
        }
    }
    static func resolve(_ choice:AppLanguage,preferred:[String])->AppLanguage {
        guard choice == .system else{return choice}
        for language in preferred {
            let base=language.replacingOccurrences(of:"_",with:"-").lowercased().split(separator:"-").first
            if base == "zh" {return .chinese}
            if base == "en" {return .english}
        }
        return .english
    }
}

enum L10n {
    static var selection:AppLanguage {
        get {AppLanguage(rawValue:UserDefaults.standard.string(forKey:"interfaceLanguage") ?? "") ?? .system}
        set {UserDefaults.standard.set(newValue.rawValue,forKey:"interfaceLanguage")}
    }
    static var language:AppLanguage {AppLanguage.resolve(selection,preferred:Locale.preferredLanguages)}
    static func text(_ key:String,language:AppLanguage?=nil,bundle:Bundle = .main)->String {
        let chosen=language ?? self.language
        guard let path=bundle.path(forResource:chosen.rawValue,ofType:"lproj"),let localized=Bundle(path:path) else{return key}
        return localized.localizedString(forKey:key,value:key,table:nil)
    }
}

// Interpolations are arguments, never translated keys. Nested messages allow
// errors and app names to stay localizable after a live language switch.
struct LocalizedMessage:ExpressibleByStringLiteral,ExpressibleByStringInterpolation {
    let key:String
    let arguments:[LocalizedMessage]
    let isVerbatim:Bool
    init(stringLiteral value:String) {key=value;arguments=[];isVerbatim=false}
    init(key:String) {self.key=key;arguments=[];isVerbatim=false}
    init(verbatim:String) {key=verbatim;arguments=[];isVerbatim=true}
    init(stringInterpolation:StringInterpolation) {
        key=stringInterpolation.key;arguments=stringInterpolation.arguments;isVerbatim=false
    }
    struct StringInterpolation:StringInterpolationProtocol {
        var key=""
        var arguments=[LocalizedMessage]()
        init(literalCapacity:Int,interpolationCount:Int) {key.reserveCapacity(literalCapacity)}
        mutating func appendLiteral(_ literal:String) {key+=literal}
        mutating func appendInterpolation(_ value:LocalizedMessage) {key+="%@";arguments.append(value)}
        mutating func appendInterpolation<T>(_ value:T) {key+="%@";arguments.append(.init(verbatim:String(describing:value)))}
    }
    func rendered(language:AppLanguage?=nil,bundle:Bundle = .main)->String {
        if isVerbatim {return key}
        let format=L10n.text(key,language:language,bundle:bundle)
        guard !arguments.isEmpty else{return format}
        return String(format:format,arguments:arguments.map{$0.rendered(language:language,bundle:bundle) as CVarArg})
    }
}
