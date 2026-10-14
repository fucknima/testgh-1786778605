#include <stdint.h>
#include <stdatomic.h>
extern void mzh_swiftui_key_interceptor(void);
extern void mzh_swiftui_text_interceptor(void);
extern void original_key(void) __asm__("_$s7SwiftUI18LocalizedStringKeyV13stringLiteralACSS_tcfC");
extern void original_text(void) __asm__("_$s7SwiftUI4TextVyACxcSyRzlufC");
__attribute__((used,section("__DATA,__interpose")))
static const struct { const void *replacement,*original; } patches[]={
 {(const void *)&mzh_swiftui_key_interceptor,(const void *)&original_key},
 {(const void *)&mzh_swiftui_text_interceptor,(const void *)&original_text}
};
static _Atomic int keyCalls,keyChanged,textCalls,textChanged;
void mzh_swiftui_mark_key(int x){atomic_fetch_add(&keyCalls,1);if(x)atomic_fetch_add(&keyChanged,1);}
void mzh_swiftui_mark_text(int x){atomic_fetch_add(&textCalls,1);if(x)atomic_fetch_add(&textChanged,1);}
__attribute__((visibility("default"))) int mzh_get_key_calls(void){return atomic_load(&keyCalls);}
__attribute__((visibility("default"))) int mzh_get_key_changed(void){return atomic_load(&keyChanged);}
__attribute__((visibility("default"))) int mzh_get_text_calls(void){return atomic_load(&textCalls);}
__attribute__((visibility("default"))) int mzh_get_text_changed(void){return atomic_load(&textChanged);}
