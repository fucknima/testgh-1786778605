#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

extern void muguet_interpose_key(void);
extern void muguet_interpose_text(void);
extern void swiftui_original_key(void) __asm__("_$s7SwiftUI18LocalizedStringKeyV13stringLiteralACSS_tcfC");
extern void swiftui_original_text(void) __asm__("_$s7SwiftUI4TextVyACxcSyRzlufC");

__attribute__((used, section("__DATA,__interpose")))
static const struct { const void *replacement, *original; } intercepts[] = {
 { (const void *)&muguet_interpose_key, (const void *)&swiftui_original_key },
 { (const void *)&muguet_interpose_text, (const void *)&swiftui_original_text }
};

static int key_calls, key_changed, text_calls, text_changed;
static int key_logged, text_logged;

static void write_diag(const char *message) {
 const char *home=getenv("HOME");
 if (!home || !*home || strlen(home)>3400) return;
 char path[4096];
 if (snprintf(path,sizeof(path),"%s/Documents/MuguetCN.log",home)>=(int)sizeof(path)) return;
 FILE *f=fopen(path,"a");
 if (!f) return;
 fprintf(f,"%lld MUGUETCN_SWIFTUI_V3 %s\n",(long long)time(NULL),message);
 fclose(f);
}

// Logs only likely untranslated Vietnamese interface strings; no network.
static unsigned long long seen_labels[256];
static int logged_labels=0;
static unsigned long long hash_label(const unsigned char *s, size_t n) {
 unsigned long long h=1469598103934665603ULL;
 for(size_t i=0;i<n;i++) { h^=s[i]; h*=1099511628211ULL; }
 return h;
}
__attribute__((visibility("default"))) void muguet_report_untranslated_ui(const char *s) {
 if(!s) return;
 size_t n=strnlen(s,150);
 if(n<3 || n>=150 || strchr(s,'\n') || strchr(s,'\r') || strchr(s,'@') || strchr(s,'/')) return;
 static const char *prefixes[]={
 "Cao","Rất","Bình","Trung","Thấp","Cực","Siêu","Mặc","Tối","Vừa","Chất","Hiệu",
 "Chế","Độ","Đồ","Hình","Âm","Tăng","Giảm","Tắt","Bật","Cài","Lưu","Xóa","Khôi",
 "Đồng","Kết","Nâng","Tùy","Lọc","Lựa","Sắc","Ánh","Tầm","Góc","Người","Xe",
 "Nhanh","Chậm","Mượt","Tự","Thủ","Không","Đang","Hòa","Giới","Thiết","Tiết",
 "Mật","Phản","Lệnh","Trở","Hủy","Xác","Hoàn","Số","Nhập"
 };
 int candidate=0;
 for(size_t i=0;i<sizeof(prefixes)/sizeof(prefixes[0]);i++) {
  size_t k=strlen(prefixes[i]);
  if(n>=k && !strncmp(s,prefixes[i],k)) { candidate=1; break; }
 }
 if(!candidate)return;
 unsigned long long h=hash_label((const unsigned char*)s,n);
 size_t slot=(size_t)(h&255);
 if(__sync_val_compare_and_swap(&seen_labels[slot],0ULL,h)!=0)return;
 if(__sync_fetch_and_add(&logged_labels,1)>=256)return;
 const char *home=getenv("HOME");
 if(!home || strlen(home)>3400)return;
 char path[4096];
 if(snprintf(path,sizeof(path),"%s/Documents/MuguetCN-untranslated.txt",home)>=(int)sizeof(path))return;
 FILE *fd=fopen(path,"a");
 if(!fd)return;
 fprintf(fd,"%s\n",s);
 fclose(fd);
}

__attribute__((visibility("default"))) void muguet_mark_key(int changed) {
 __sync_fetch_and_add(&key_calls,1);
 if (changed) {
  __sync_fetch_and_add(&key_changed,1);
  if (__sync_bool_compare_and_swap(&key_logged,0,1)) write_diag("KEY_TRANSLATED");
 }
}
__attribute__((visibility("default"))) void muguet_mark_text(int changed) {
 __sync_fetch_and_add(&text_calls,1);
 if (changed) {
  __sync_fetch_and_add(&text_changed,1);
  if (__sync_bool_compare_and_swap(&text_logged,0,1)) write_diag("TEXT_TRANSLATED");
 }
}
__attribute__((visibility("default"))) int muguet_get_key_calls(void){return key_calls;}
__attribute__((visibility("default"))) int muguet_get_key_changed(void){return key_changed;}
__attribute__((visibility("default"))) int muguet_get_text_calls(void){return text_calls;}
__attribute__((visibility("default"))) int muguet_get_text_changed(void){return text_changed;}
__attribute__((constructor)) static void marker(void){
 write_diag("LOADED");
 if(getenv("MUGUETCN_DIAG")) fprintf(stderr,"MUGUETCN_INJECTED=YES\n");
}
