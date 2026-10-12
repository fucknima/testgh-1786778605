import SwiftUI
import Foundation
import Darwin
let localized: LocalizedStringKey = "Bảng lệnh cheat"
let literalView = Text("Cài đặt & Tùy chọn")
let dynamicTitle: String = "Nhân vật"
let dynamicView = Text(dynamicTitle)
withExtendedLifetime((localized, literalView, dynamicView)) { }
let selfHandle = dlopen(nil, RTLD_NOW)
func count(_ name: String) -> Int32 {
 guard let symbol = dlsym(selfHandle,name) else { return -1 }
 return unsafeBitCast(symbol, to: (@convention(c) () -> Int32).self)()
}
let kc=count("muguet_get_key_calls"), kt=count("muguet_get_key_changed")
let tc=count("muguet_get_text_calls"), tt=count("muguet_get_text_changed")
print("MUGUETCN_PROBE: key_calls=\(kc) key_translated=\(kt) text_calls=\(tc) text_translated=\(tt)")
if kc < 1 || kt < 1 || tc < 1 || tt < 1 { exit(81) }
print("MUGUETCN_PROBE: PASS")
