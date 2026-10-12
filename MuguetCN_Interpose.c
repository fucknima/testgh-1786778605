#include <stdio.h>
#include <stdlib.h>
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
__attribute__((visibility("default"))) void muguet_mark_key(int changed) {
 __sync_fetch_and_add(&key_calls,1);
 if(changed) __sync_fetch_and_add(&key_changed,1);
}
__attribute__((visibility("default"))) void muguet_mark_text(int changed) {
 __sync_fetch_and_add(&text_calls,1);
 if(changed) __sync_fetch_and_add(&text_changed,1);
}
__attribute__((visibility("default"))) int muguet_get_key_calls(void){return key_calls;}
__attribute__((visibility("default"))) int muguet_get_key_changed(void){return key_changed;}
__attribute__((visibility("default"))) int muguet_get_text_calls(void){return text_calls;}
__attribute__((visibility("default"))) int muguet_get_text_changed(void){return text_changed;}
__attribute__((constructor)) static void marker(void){
 if(getenv("MUGUETCN_DIAG")) fprintf(stderr,"MUGUETCN_INJECTED=YES\n");
}
