/*
 * Muguet 8.8 non-invasive Chinese UI display translation (iOS 15+, arm64).
 * Does not write to Muguet's code/data segments, cheat IDs, HUD tables, or memory.
 * Only intercepts UIKit display setters and NSBundle localization lookup.
 * Build with Apple Xcode iOS SDK. Inject with a sideload tool that supports dylibs.
 * NOTICE: Untested on real device; SwiftUI verbatim Text may bypass these hooks.
 */
typedef __SIZE_TYPE__ size_t;
#ifndef NULL
#define NULL ((void*)0)
#endif
extern int strcmp(const char *, const char *);

typedef void *Obj;
typedef void *Sel;
typedef void *Meth;
typedef void *Imp;

extern Obj objc_getClass(const char *name);
extern Sel sel_registerName(const char *name);
extern Meth class_getInstanceMethod(Obj cls, Sel name);
extern Imp method_setImplementation(Meth method, Imp imp);
extern Obj objc_msgSend(Obj receiver, Sel selector, ...);

struct Translation { const char *source; const char *zh; };
static const struct Translation kTranslations[] = {
    {" người chơi trực tuyến cùng lúc.", "名玩家同时在线。"},
    {" người): Kết nối qua: ", "人），连接地址："},
    {" player(s)", " 位玩家"},
    {"1. Chọn Chế độ phòng:", "1. 选择房间模式："},
    {"100 % (Độ phân giải gốc)", "100%（原生分辨率）"},
    {"120 FPS Siêu Mượt", "120帧高流畅度"},
    {"120 fps (Mở khóa 120 FPS / ProMotion)", "120帧（ProMotion高刷）"},
    {"1ST POV", "第一人称"},
    {"1ST POV (Góc nhìn thứ 1)", "第一人称视角"},
    {"2. Luật sát thương (PvP):", "2. PvP伤害规则："},
    {"3. Số người chơi tối đa (Server capacity):", "3. 房间人数上限："},
    {"30 fps (Tiết kiệm pin)", "30帧（省电）"},
    {"32 Người chơi", "32名玩家"},
    {"35 % (Siêu nhẹ)", "35%低画质"},
    {"4. Mã phòng chia sẻ cho bạn bè:", "4. 分享给好友的房间码："},
    {"50 %", "50%"},
    {"50 % (Khuyên dùng cho 120 FPS)", "50%（120帧推荐）"},
    {"60 fps", "60 帧"},
    {"60 fps (Mặc định)", "60帧（默认）"},
    {"64 Người chơi", "64名玩家"},
    {"65 % (Cân bằng)", "65%（均衡）"},
    {"AIM", "瞄准"},
    {"AIM (Ngắm / Phanh)", "瞄准/刹车"},
    {"After a crash, reopen Muguet and share the previous log. Logs contain connection addresses and runtime errors, not game files.", "崩溃后重启Muguet并分享上次日志。日志只含连接地址和运行错误，不包含游戏文件。"},
    {"Aim while firing", "开火时瞄准"},
    {"Apply", "应用"},
    {"Audio", "声音"},
    {"Back", "返回"},
    {"Bình thường (Chống tụt FPS đồi núi)", "普通（减少山地场景掉帧）"},
    {"Bình thường (Mượt nhất)", "普通（最流畅）"},
    {"Bình thường (Tối ưu FPS)", "普通（优先帧率）"},
    {"Bình thường / Thấp (Ít tốn RAM)", "普通/低（节省内存）"},
    {"Bơi siêu nhanh", "超级游泳"},
    {"Bảng lệnh cheat", "秘籍菜单"},
    {"Bất tử 5 phút", "无敌 5 分钟"},
    {"Bật chế độ Multiplayer", "启用多人联机模式"},
    {"Bắn ra đạn thiêu đốt mục tiêu", "燃烧弹：子弹可点燃目标"},
    {"CAM", "镜头"},
    {"CAM (Góc camera)", "切换镜头"},
    {"COVER", "掩体"},
    {"COVER (Núp / Radio)", "掩体/电台"},
    {"CROUCH", "蹲下"},
    {"CROUCH (Ngồi / Nhìn sau)", "蹲下（下蹲 / 后视）"},
    {"Cancel", "取消"},
    {"Cao (Bloom & Tia nắng)", "高（泛光/光束）"},
    {"Chiến đấu", "战斗"},
    {"Chơi Online (Multiplayer)", "在线多人游戏"},
    {"Chạy siêu nhanh", "超级奔跑"},
    {"Chất lượng Cỏ cây & Thảo mộc (Grass)", "草地与植被质量"},
    {"Chất lượng Hạt & Hiệu ứng cháy nổ (Particles)", "粒子与爆炸效果质量"},
    {"Chất lượng Mặt nước (Water)", "水面质量"},
    {"Chất lượng Phản chiếu (Reflections)", "反射质量"},
    {"Chất lượng Textures", "纹理质量"},
    {"Chất lượng Đổ bóng (Shadows)", "阴影质量"},
    {"Chế độ chơi (Story / Sandbox) và luật PvP tự động đồng bộ theo mã phòng của chủ phòng.", "游戏模式（剧情 / 自由探索）及 PvP 规则会根据房主的房间码自动同步。"},
    {"Chế độ phòng", "房间模式"},
    {"Chế độ say rượu", "醉酒模式"},
    {"Chỉnh vị trí & Kích thước nút trực quan (HUD Editor)", "可视化调整按钮位置与大小（HUD 编辑器）"},
    {"Chỉnh vị trí & kích thước nút (HUD)", "调整按钮的位置和大小（HUD）"},
    {"Close", "关闭"},
    {"Controls", "操作设置"},
    {"Could not save settings: ", "无法保存设置："},
    {"Cài đặt & Tùy chọn", "设置与选项"},
    {"Cấu hình Đồ họa & Kích hoạt 120 FPS", "图形设置与开启120帧"},
    {"Disable", "关闭"},
    {"Done", "完成"},
    {"Drag on the right FIRE button to adjust aim while shooting. The left FIRE button frees your right thumb to aim.", "拖动右侧开火键可同时瞄准和射击。左侧开火键可以让右手专注瞄准。"},
    {"ENTER", "上下车"},
    {"ENTER (Lên/xuống xe)", "上车 / 下车"},
    {"Enable", "启用"},
    {"Exit", "退出"},
    {"FIRE", "开火"},
    {"FIRE (Bắn / Ga)", "开火/油门"},
    {"FIRE phụ (Bắn trái)", "左侧开火"},
    {"FPS", "帧率"},
    {"Fatal error", "错误"},
    {"Game", "游戏"},
    {"Giảm mức độ truy nã về 0", "将通缉等级降为 0"},
    {"Giới hạn người chơi", "玩家人数上限"},
    {"Graphics", "画质设置"},
    {"High", "高"},
    {"Hiện bảng HUD Editor", "显示 HUD 编辑器"},
    {"Hiệu ứng slow-motion điện ảnh", "电影式慢动作效果"},
    {"Host", "创建房间"},
    {"Hòa bình Co-op", "和平合作"},
    {"Hòa bình: Không gây sát thương lẫn nhau, tránh bắn nhau khi spawn.", "和平模式下玩家之间无法互相造成伤害，避免出生点交火。"},
    {"Hậu kỳ & Ánh sáng (Post FX)", "后期效果与光照"},
    {"Hồi phục 100% máu, giáp và sửa xe", "回满生命、护甲并修车"},
    {"Import game data .zip", "导入游戏.zip"},
    {"Import other game data…", "导入其他游戏包"},
    {"In game: save via Phone > Quick Save, or Pause > Game > Save Game. Saves are stored in Files app > On My iPhone > Muguet > saves.", "通过手机或暂停菜单保存游戏，存档路径：“文件”>“我的iPhone”>Muguet>saves。"},
    {"JOYSTICK", "摇杆"},
    {"JOYSTICK (Cần di chuyển)", "虚拟摇杆（移动）"},
    {"JUMP", "跳跃"},
    {"JUMP (Nhảy / Phanh tay)", "跳跃/手刹"},
    {"Join", "加入"},
    {"Khoảng cách Đổ bóng (Shadow Distance)", "阴影距离"},
    {"Khóa nhịp ProMotion V-Sync 120Hz (CADisplayLink)", "ProMotion 120Hz 垂直同步"},
    {"Khôi phục mặc định nút bấm", "恢复按钮默认设置"},
    {"Khôi phục đồ họa (Fix màn hình đen)", "恢复画面设置（修复黑屏）"},
    {"Khôi phục đồ họa gốc (Sửa lỗi màn hình đen)", "恢复默认画质（修复黑屏）"},
    {"Không nhận sát thương trong 5 phút", "5 分钟内免受伤害"},
    {"Khử răng cưa viền (FXAA)", "快速抗锯齿（FXAA）"},
    {"Kích hoạt hiệu ứng tuyết rơi toàn map", "在整张地图启用下雪效果"},
    {"Kích thước nút", "按钮大小"},
    {"Language", "语言"},
    {"Look sensitivity", "视角灵敏度"},
    {"Làm chậm khi ngắm", "瞄准时慢动作"},
    {"Làm chậm thời gian khi giữ nút ngắm", "按住瞄准键时减慢时间"},
    {"Làm chậm toàn game", "全局慢动作"},
    {"Lưu & Áp dụng", "保存并应用"},
    {"Lưu ý: Luật sát thương PvP và Chế độ chơi hoàn toàn tuân theo chủ phòng, không thể tự đổi.", "注意：PvP 规则和游戏模式由房主统一设定，加入者无法自行更改。"},
    {"Lệnh Cheat GTA V", "GTA V 秘籍"},
    {"Lệnh Cheat GTA V (Chỉ Offline)", "GTA V单机秘籍"},
    {"Lọc vân bề mặt (Anisotropic Filtering)", "各向异性过滤"},
    {"MENU", "菜单"},
    {"MENU (Muguet Menu)", "菜单（Muguet）"},
    {"MENU KEYS", "方向键"},
    {"MENU KEYS (Phím mũi tên)", "方向键"},
    {"Mode", "游戏模式"},
    {"Muguet", "Muguet"},
    {"Muguet Menu", "Muguet 菜单"},
    {"Multiplayer", "多人联机"},
    {"Mute audio", "静音"},
    {"Máy bay Stunt Plane", "特技飞机"},
    {"Máy bay cánh quạt cổ điển", "经典螺旋桨飞机"},
    {"Máy bay nhào lộn cánh quạt", "螺旋桨特技飞机"},
    {"Máy chủ (Nâng cao)", "服务器（高级）"},
    {"Mô tô đua PCJ-600", "PCJ-600 摩托车"},
    {"Mô tô địa hình vượt đồi núi", "适合山地越野的摩托车"},
    {"Mật khẩu phòng (Tùy chọn)", "房间密码（可选）"},
    {"Mật khẩu phòng (nếu chủ phòng đặt)", "房间密码（如房主已设置）"},
    {"Mật độ & Đa dạng Người đi bộ (Pedestrians)", "行人数量与多样性"},
    {"Mật độ Xe cộ trên đường (Traffic)", "道路车辆密度"},
    {"Mỗi phát bắn tạo ra vụ nổ lớn", "每发子弹引发强烈爆炸"},
    {"Mở phòng trên Wi-Fi (Tối đa ", "局域网 Wi-Fi 开房（最多"},
    {"Ngắn (0.5× - Tiết kiệm RAM)", "短（0.5倍—节省内存）"},
    {"Nhân vật", "角色"},
    {"Nhảy cao gấp 10 lần bình thường", "超级跳跃（约 10 倍高度）"},
    {"Nhận dù để nhảy từ trên cao", "获得用于高空跳伞的降落伞"},
    {"Nhận full tất cả vũ khí và đạn", "获得全部武器及弹药"},
    {"Nhập lệnh tùy chỉnh", "输入自定义秘籍"},
    {"Nhập mã lệnh (vd: PAINKILLER)", "输入秘籍码(如PAINKILLER)"},
    {"Nhập mã phòng (vd: SP-8621) để vào chơi cùng bạn bè.", "请输入房间码（如 SP-8621）与好友一起游戏。"},
    {"Nhập mã phòng:", "输入房间码："},
    {"Nhập tên nhân vật...", "输入角色名称…"},
    {"Nhập địa chỉ máy chủ để kết nối.", "请输入服务器地址以连接。"},
    {"Nạp đầy thanh kỹ năng nhân vật", "填满角色的特殊能力槽"},
    {"Nắm đấm phát nổ", "爆炸拳击"},
    {"OK", "确定"},
    {"Off", "关"},
    {"On", "开"},
    {"Online: connected ", "在线：已连接 "},
    {"PAUSE", "暂停"},
    {"PAUSE (Tạm dừng)", "暂停游戏"},
    {"PHONE", "手机"},
    {"PHONE (Điện thoại)", "手机"},
    {"Pause", "暂停"},
    {"Phân vùng công khai", "公共联机区域"},
    {"Phương tiện", "载具"},
    {"Play", "开始游戏"},
    {"PvP Bật: Người chơi có thể bắn và tiêu diệt nhau.", "开启 PvP：允许玩家互相射击和击败对方。"},
    {"RELOAD", "换弹"},
    {"RELOAD (Nạp đạn / Còi)", "装弹（换弹 / 鸣笛）"},
    {"Reset", "重置"},
    {"Resolution", "渲染分辨率"},
    {"Resume", "继续游戏"},
    {"Rơi tự do từ trời", "空中自由落体"},
    {"SWITCH", "切换角色"},
    {"SWITCH (Đổi nhân vật)", "切换角色"},
    {"Sandbox", "自由模式"},
    {"Sandbox (Tự do)", "自由模式"},
    {"Save", "保存"},
    {"Server AWS iOSVN Singapore (Ping ~40ms, Hỗ trợ 32 / 64 người)", "新加坡 AWS iOSVN 服务器（约40ms，支持32/64人）"},
    {"Session", "联机方式"},
    {"Settings", "设置"},
    {"Share / Backup saves", "分享/备份存档"},
    {"Share startup / memory logs", "分享启动 / 内存日志"},
    {"Story Mode", "剧情模式"},
    {"Story Mode (Cốt truyện)", "剧情模式"},
    {"Story Mode Public", "公共剧情"},
    {"Sảnh chung công khai (Hỗ trợ 32 / 64 người/phòng)", "公共大厅（每间房最多32/64人）"},
    {"Textures", "纹理质量"},
    {"Thay đổi nắng, mưa, bão sấm chớp", "切换晴天、雨天、暴风雨和雷电"},
    {"This build has no game code: build it with ./make-ios.sh <game.zip>.", "缺少游戏代码，请用 ./make-ios.sh <game.zip> 编译。"},
    {"Thiết lập trực tiếp các thông số đồ họa của GTA V ngay tại đây mà không cần chỉnh trong game.", "可以在此直接调整 GTA V 的画质参数，不必进入游戏设置。"},
    {"Thoát hẳn ứng dụng (Exit)", "彻底退出应用"},
    {"Thoát ứng dụng", "退出应用"},
    {"Thông báo Đồ họa", "画面设置提示"},
    {"Thả nhân vật từ trên chín tầng mây", "将角色传送至高空并开始自由落体"},
    {"Thấp (0% - Tiết kiệm RAM)", "低（0%—节省内存）"},
    {"Thế giới", "世界"},
    {"Tiêu chuẩn (0.0)", "标准（0.0）"},
    {"Tiêu chuẩn (1.0×)", "标准（1.0倍）"},
    {"Tiếp tục (Resume)", "继续游戏"},
    {"Tiếp tục chơi", "继续游戏"},
    {"Tiết Kiệm RAM", "节省内存"},
    {"Tiết kiệm RAM (-0.5)", "节省内存（-0.5）"},
    {"Touch Controls", "触控设置"},
    {"Tra cứu và kích hoạt nhanh các lệnh cheat (Bất tử, full vũ khí, trực thăng, xe đua...). Lệnh cheat tự động bị khóa trong chế độ Online.", "快速查找并使用 GTA V 秘籍（无敌、全武器、直升机、赛车等）。在线模式下自动禁用秘籍。"},
    {"Trang bị Dù nhảy", "获得降落伞"},
    {"Trọng lực Mặt Trăng", "月球重力"},
    {"Trực thăng Buzzard", "秃鹰攻击直升机"},
    {"Trực thăng chiến đấu có súng & tên lửa", "配备机枪和导弹的攻击直升机"},
    {"Tàu lặn khám phá đáy đại dương", "驾驶潜水艇探索海底"},
    {"Tàu ngầm Kraken", "海妖潜水艇"},
    {"Tên nhân vật / Người chơi", "角色 / 玩家名称"},
    {"Tên này sẽ hiển thị trên đầu nhân vật của bạn khi chơi cùng bạn bè.", "与好友联机时，该名字将显示在你的角色头顶。"},
    {"Tùy chỉnh Giao diện Nút Bấm (Touch Controls)", "自定义触屏按钮布局"},
    {"Tăng 1 sao cảnh sát", "增加 1 颗通缉星"},
    {"Tăng thêm 1 cấp độ truy nã", "通缉等级提高 1 级"},
    {"Tăng tốc độ bơi dưới nước", "提高水下游泳速度"},
    {"Tăng tốc độ di chuyển tối đa", "大幅提高奔跑速度"},
    {"Tạo phòng hỗ trợ tối đa ", "房间最多支持"},
    {"Tất cả Vũ khí", "全部武器"},
    {"Tầm nhìn xa & Chi tiết vật thể (LOD Scale)", "可视距离与物体细节"},
    {"Tầm nhìn xa (+0.5)", "远距(+0.5)"},
    {"Tốc độ khung hình (Frame Limit)", "帧率上限"},
    {"Tối ưu đồ họa sâu (Deep Optimization 60-120 FPS Boost)", "深度画质优化（提升60至120帧性能）"},
    {"Tự động khống chế bóng đổ, cỏ rậm và khử răng cưa trong GTA V settings.xml để duy trì FPS tối đa khi máy nóng.", "自动调整 GTA V settings.xml 中的阴影、草地与抗锯齿参数，减轻设备发热时的性能下降。"},
    {"Tự động kết nối vào sảnh chung với người chơi trực tuyến trên server AWS iOSVN. Chế độ Hòa bình bật mặc định.", "自动连接到 AWS iOSVN 服务器的公共大厅，与在线玩家一起游玩。默认开启和平模式。"},
    {"Unknown error", "未知错误"},
    {"Very High", "非常高"},
    {"Ví dụ: SP-8621 hoặc BX-5520", "例如：SP-8621 或 BX-5520"},
    {"Vắng vẻ (0% - Mượt nhất)", "稀疏（0%—最流畅）"},
    {"Vừa phải (50%)", "适中（50%）"},
    {"WEAPON", "武器"},
    {"WEAPON (Vũ khí)", "切换武器"},
    {"Xe Porsche 2 cửa siêu tốc", "高速双门保时捷"},
    {"Xe bọc thép Duke O'Death", "末日公爵防弹车"},
    {"Xe chở rác bọc thép húc xe khác", "大型垃圾车，可撞击其他车辆"},
    {"Xe cào cào Sanchez", "Sanchez越野摩托"},
    {"Xe cơ bắp chống đạn chống nổ cực mạnh", "装甲肌肉车，具有较强防弹和防爆能力"},
    {"Xe máy phân khối lớn tốc độ cao", "高速大排量摩托车"},
    {"Xe rác Trashmaster", "垃圾车"},
    {"Xe sang trọng kéo dài", "加长豪华轿车"},
    {"Xe thể thao Comet", "Comet跑车"},
    {"Xe thể thao cao cấp", "高性能豪华跑车"},
    {"Xe và người bay lơ lửng nhẹ", "车辆与人物会缓慢飘浮"},
    {"Xe đua Rapid GT", "Rapid GT 跑车"},
    {"Xe đạp biểu diễn nhào lộn", "特技自行车"},
    {"Xem & Kích hoạt Lệnh Cheat", "查看并使用秘籍"},
    {"Xóa sao cảnh sát", "清除通缉星级"},
    {"proudly made by c22dev", "由 c22dev 制作"},
    {"unknown error", "未知错误"},
    {"x16 (Rõ nét mặt đường)", "16倍（路面纹理清晰）"},
    {"Đi đứng lảo đảo hiệu ứng say xỉn", "角色进入醉酒状态并摇晃行走"},
    {"Đã gửi lệnh cheat: ", "已执行秘籍："},
    {"Đã khôi phục cài đặt đồ họa Rockstar GTA V về mặc định an toàn (Shader High, MSAA Tắt, Bóng Normal, 120 FPS). Lỗi màn hình đen do Max Setting đã được xử lý triệt để!", "已恢复 GTA V 的安全默认画质参数：着色器高、关闭MSAA、普通阴影、120帧设置，以尝试修复极高画质导致的黑屏问题。"},
    {"Đã kích hoạt Cấu hình Siêu Tiết Kiệm RAM (~800MB)!", "已启用超低内存配置（约800MB）！"},
    {"Đã kích hoạt cấu hình 120 FPS Siêu Mượt!", "已启用120帧高流畅度配置！"},
    {"Đã đưa toàn bộ nút về mặc định", "已将全部按钮恢复默认"},
    {"Đã đặt lại ", "已重置 "},
    {"Đã đồng bộ tự động", "已自动同步"},
    {"Đông đúc (100% - Như PC)", "密集(100%/PC)"},
    {"Đông đúc (100%)", "密集（100%）"},
    {"Đấm kẻ địch văng xa và phát nổ", "拳击敌人时将其击飞并爆炸"},
    {"Đầy Máu & Giáp", "补满血甲"},
    {"Đầy kỹ năng", "技能值全满"},
    {"Đặt lại nút", "重置按钮"},
    {"Đặt lại tất cả", "全部重置"},
    {"Đồng bộ chính xác với tần số quét 60Hz/120Hz của màn hình iPhone/iPad để triệt tiêu khựng hình và giữ khung hình 120 FPS mượt nhất.", "与 iPhone/iPad 的60/120Hz屏幕刷新率同步，减少画面微卡顿，改善高帧率稳定性。"},
    {"Đổi thời tiết", "切换天气"},
    {"Độ phân giải (Resolution)", "渲染分辨率"},
    {"⚔️ Đấu trường (PvP)", "⚔️ 玩家对战（PvP）"},
    {"🎮 Cài đặt Đồ họa GTA V Chi tiết (In-Game Graphics)", "🎮 GTA V 游戏内高级画质设置"},
    {"💡 Hướng dẫn cài đặt nhanh qua ứng dụng Tệp:", "💡 通过“文件”应用快速导入游戏："},
    {"📦 Lưu ý dung lượng: Game đầy đủ chiếm ~21 GB. Nếu giải nén trực tiếp trên iPhone/iPad cần trống tối thiểu 42 GB (21 GB zip + 21 GB giải nén; sau khi xong xóa file zip đi còn 21 GB). Giải nén", "📦 存储空间提示：游戏解压后约占21GB；如果直接在 iPhone/iPad 上解压，请预留至少42GB（压缩包21GB＋解压文件21GB）。解压完成后可以删除压缩包。"},
    {"📦 Lưu ý dung lượng: Game đầy đủ chiếm ~21 GB. Nếu giải nén trực tiếp trên iPhone/iPad cần trống tối thiểu 42 GB (21 GB zip + 21 GB giải nén; sau khi xong xóa file zip đi còn 21 GB). Giải nén trước trên máy tính rồi chép vào sẽ chỉ tốn 21 GB bộ nhớ máy.", "📦 存储空间：完整游戏约21GB。在iPhone/iPad上直接解压需要约42GB可用空间（压缩包和解压文件各21GB）。解压后可以删除压缩包。也可以先在电脑解压，再复制到手机以节省空间。"},
    {"🛡️ Hòa bình (Co-op)", "🛡️ 和平合作"},
};
static const size_t kTranslationCount = sizeof(kTranslations)/sizeof(kTranslations[0]);

static Obj translated(Obj source) {
    if (!source) return source;
    Sel utf8 = sel_registerName("UTF8String");
    const char *text = ((const char *(*)(Obj,Sel))objc_msgSend)(source,utf8);
    if (!text) return source;
    for (size_t i=0; i<kTranslationCount; ++i) {
        if (strcmp(text,kTranslations[i].source) != 0) continue;
        Obj cls=objc_getClass("NSString");
        if (!cls) return source;
        return ((Obj (*)(Obj,Sel,const char*))objc_msgSend)(cls,sel_registerName("stringWithUTF8String:"),kTranslations[i].zh);
    }
    return source;
}

static Obj (*original_localize)(Obj,Sel,Obj,Obj,Obj) = NULL;
static Obj localized(Obj self,Sel _cmd,Obj key,Obj value,Obj table) {
    if (!original_localize) return key;
    Obj lookedUp=original_localize(self,_cmd,key,value,table);
    Obj candidate=translated(lookedUp);
    if (candidate != lookedUp) return candidate;
    return translated(key)==key ? lookedUp : translated(key);
}

static void (*original_labelText)(Obj,Sel,Obj)=NULL;
static void labelText(Obj self,Sel cmd,Obj text){
    if(original_labelText) original_labelText(self,cmd,translated(text));
}

static void (*original_buttonTitle)(Obj,Sel,Obj,long)=NULL;
static void buttonTitle(Obj self,Sel cmd,Obj text,long state){
    if(original_buttonTitle) original_buttonTitle(self,cmd,translated(text),state);
}

static void (*original_setPlaceHolder)(Obj,Sel,Obj)=NULL;
static void setPlaceHolder(Obj self,Sel cmd,Obj text){
    if(original_setPlaceHolder) original_setPlaceHolder(self,cmd,translated(text));
}

static void (*original_navigationTitle)(Obj,Sel,Obj)=NULL;
static void navigationTitle(Obj self,Sel cmd,Obj text){
    if(original_navigationTitle) original_navigationTitle(self,cmd,translated(text));
}

static void (*original_barTitle)(Obj,Sel,Obj)=NULL;
static void barTitle(Obj self,Sel cmd,Obj text){
    if(original_barTitle) original_barTitle(self,cmd,translated(text));
}

static void (*original_segmentTitle)(Obj,Sel,Obj,long)=NULL;
static void segmentTitle(Obj self,Sel cmd,Obj text,long idx){
    if(original_segmentTitle) original_segmentTitle(self,cmd,translated(text),idx);
}

static void swizzle(const char *className,const char *selector,Imp replacement,Imp *original){
    Obj klass=objc_getClass(className);
    if (!klass) return;
    Meth method=class_getInstanceMethod(klass,sel_registerName(selector));
    if (!method) return;
    *original=method_setImplementation(method,replacement);
}

__attribute__((constructor)) static void initializeMuguetCN(void){
    swizzle("NSBundle","localizedStringForKey:value:table:",(Imp)localized,(Imp*)&original_localize);
    swizzle("UILabel","setText:",(Imp)labelText,(Imp*)&original_labelText);
    swizzle("UIButton","setTitle:forState:",(Imp)buttonTitle,(Imp*)&original_buttonTitle);
    swizzle("UITextField","setPlaceholder:",(Imp)setPlaceHolder,(Imp*)&original_setPlaceHolder);
    swizzle("UINavigationItem","setTitle:",(Imp)navigationTitle,(Imp*)&original_navigationTitle);
    swizzle("UIBarButtonItem","setTitle:",(Imp)barTitle,(Imp*)&original_barTitle);
    swizzle("UISegmentedControl","setTitle:forSegmentAtIndex:",(Imp)segmentTitle,(Imp*)&original_segmentTitle);
}