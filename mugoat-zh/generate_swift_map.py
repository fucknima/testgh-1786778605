#!/usr/bin/env python3
import json
from pathlib import Path
p=Path(__file__).resolve().parent
eng=json.loads((p/"translations_zh.json").read_text(encoding="utf-8"))
extra=json.loads((p/"ui_extras_zh.json").read_text(encoding="utf-8"))
assert len(eng)==269 and len(extra)>=128
supplement={
 "Nhân vật":"角色","Phương tiện":"载具","Chiến đấu":"战斗","Thế giới":"世界",
 "Bật":"启用","Đóng":"关闭","Áp dụng":"应用","Lệnh Cheat GTA V":"GTA V 秘籍",
 "Quản lý Mod":"模组管理","Bảng lệnh cheat":"秘籍列表","Mod":"模组",
 "Cài đặt Mod":"安装模组","Tải Mod":"加载模组","Tắt Mod":"禁用模组",
 "Kích hoạt":"启用","Đã bật":"已启用","Đã tắt":"已禁用",
 "Nhập Mod":"导入模组","Làm mới":"刷新","Xóa":"删除","Hủy":"取消",
 "Không có Mod":"没有模组","Tìm kiếm":"搜索","Tiếng Việt":"简体中文"
}
mapping={**eng,**extra,**supplement}
lines=["// Auto-generated display-only dictionary","import Foundation","enum MZHStrings {"," static let exact: [String:String] = ["]
lines.extend("  "+json.dumps(k,ensure_ascii=False)+": "+json.dumps(v,ensure_ascii=False)+"," for k,v in sorted(mapping.items()))
lines += [" ]","}"]
(p/"MugoatZHGenerated.swift").write_text("\n".join(lines)+"\n",encoding="utf-8")
print("Translation keys",len(mapping))
