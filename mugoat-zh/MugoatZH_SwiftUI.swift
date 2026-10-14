import Foundation
import SwiftUI
private enum MZH {
    static let enabled: Bool = {
        let name = Bundle.main.executableURL?.lastPathComponent ?? ""
        #if os(macOS)
        return name == "MugoatZHProbe"
        #else
        return name == "PlayGTA5Native"
        #endif
    }()
    static let prefixes: [(String,String)] = [
        ("Game chưa chạy: ", "游戏尚未运行："),
        ("Đang kích hoạt cheat: ", "正在启用秘籍："),
        ("Đã gửi lệnh cheat: ", "已发送秘籍：")
    ]
    static func translate(_ s:String) -> String? {
        guard enabled && !s.isEmpty && s.utf8.count <= 4096 else { return nil }
        if let direct=MZHStrings.exact[s] {return direct}
        for (old,zh) in prefixes where s.hasPrefix(old) {
            return zh+String(s.dropFirst(old.count))
        }
        return nil
    }
}
@_silgen_name("mzh_swiftui_mark_key")
private func markKey(_ changed:Int32)
@_silgen_name("mzh_swiftui_mark_text")
private func markText(_ changed:Int32)
extension LocalizedStringKey {
    @_silgen_name("mzh_swiftui_key_interceptor")
    public init(mzhRaw source:String) {
        let translated=MZH.translate(source)
        markKey(translated == nil ? 0 : 1)
        self.init(stringLiteral: translated ?? source)
    }
}
extension Text {
    @_silgen_name("mzh_swiftui_text_interceptor")
    public init<S:StringProtocol>(mzhRaw source:S) {
        let translated=MZH.translate(String(source))
        markText(translated == nil ? 0 : 1)
        if let translated {self.init(verbatim:translated)}
        else {self.init(source)}
    }
}
