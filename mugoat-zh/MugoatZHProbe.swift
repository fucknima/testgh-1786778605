import SwiftUI
import Foundation
import Darwin
let a:LocalizedStringKey="Nhân vật"
let b:LocalizedStringKey="Chọn thao tác cho bản mod này:"
let c:LocalizedStringKey="Bật"
let d:LocalizedStringKey="Đóng"
let e=Text("Phương tiện")
let f=Text("Quản lý Mod")
let t1="Bất tử 5 phút",t2="Xóa vĩnh viễn",t3="Tìm kiếm lệnh cheat...",t4="Không nhận sát thương trong 5 phút"
let g=Text(t1),h=Text(t2),i=Text(t3),j=Text(t4)
withExtendedLifetime((a,b,c,d,e,f,g,h,i,j)){}
let handle=dlopen(nil,RTLD_NOW)
func get(_ name:String)->Int32 {
 guard let ptr=dlsym(handle,name) else {return -1}
 return unsafeBitCast(ptr,to:(@convention(c)()->Int32).self)()
}
let k=get("mzh_get_key_calls"),kc=get("mzh_get_key_changed")
let t=get("mzh_get_text_calls"),tc=get("mzh_get_text_changed")
print("MUGOAT_ZH_PROBE key=\(k)/\(kc) text=\(t)/\(tc)")
if k<4 || kc<4 || t<4 || tc<4 {exit(81)}
print("MUGOAT_ZH_PROBE_PASS")
