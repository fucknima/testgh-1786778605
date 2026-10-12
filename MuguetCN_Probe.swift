import SwiftUI
import Foundation
import Darwin
let localized: LocalizedStringKey = "Bảng lệnh cheat"
let literalView = Text("Cài đặt & Tùy chọn")
let dynamicTitle: String = "Nhân vật"
let dynamicView = Text(dynamicTitle)
let highTitle = "Cao"
let veryHighTitle = "Rất cao"
let lowTitle = "Thấp"
let levels = (Text(highTitle), Text(veryHighTitle), Text(lowTitle))
let staticVeryHigh: LocalizedStringKey = "Rất cao"
let unknownTitle = "Rất đẹp"
let unknownView = Text(unknownTitle)
withExtendedLifetime((localized, literalView, dynamicView, levels, staticVeryHigh, unknownView)) { }
let selfHandle = dlopen(nil, RTLD_NOW)
func count(_ name: String) -> Int32 {
 guard let symbol = dlsym(selfHandle,name) else { return -1 }
 return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)()
}
let kc=count("muguet_get_key_calls"), kt=count("muguet_get_key_changed")
let tc=count("muguet_get_text_calls"), tt=count("muguet_get_text_changed")
print("MUGUETCN_PROBE: key_calls=\(kc) key_translated=\(kt) text_calls=\(tc) text_translated=\(tt)")
if kc < 3 || kt < 3 || tc < 5 || tt < 4 { exit(81) }
print("MUGUETCN_PROBE: PASS")
