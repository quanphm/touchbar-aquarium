#import "TouchBarPrivate.h"
#import <dlfcn.h>
#import <objc/runtime.h>

// These are Apple-private APIs. They are looked up dynamically (via the ObjC
// runtime and dlsym) so we never link against a private framework or name a
// private selector at compile time. If they are ever removed, the call sites
// simply report "unavailable" and the app falls back to the public API.

#pragma mark - NSTouchBar private class methods

static BOOL TBInvokePresent(NSTouchBar *bar, long long placement,
                            NSTouchBarItemIdentifier identifier, NSString *selectorName) {
    SEL sel = NSSelectorFromString(selectorName);
    Method method = class_getClassMethod([NSTouchBar class], sel);
    if (!method) return NO;
    typedef void (*Fn)(id, SEL, NSTouchBar *, long long, NSTouchBarItemIdentifier);
    ((Fn)method_getImplementation(method))([NSTouchBar class], sel, bar, placement, identifier);
    return YES;
}

static void TBInvokeBar(NSTouchBar *bar, NSString *selectorName) {
    SEL sel = NSSelectorFromString(selectorName);
    Method method = class_getClassMethod([NSTouchBar class], sel);
    if (!method) return;
    typedef void (*Fn)(id, SEL, NSTouchBar *);
    ((Fn)method_getImplementation(method))([NSTouchBar class], sel, bar);
}

BOOL TBPresentSystemModal(NSTouchBar *touchBar, long long placement, NSTouchBarItemIdentifier identifier) {
    // macOS 10.14+
    if (TBInvokePresent(touchBar, placement, identifier, @"presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"))
        return YES;
    // macOS 10.13
    if (TBInvokePresent(touchBar, placement, identifier, @"presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:"))
        return YES;
    return NO;
}

void TBDismissSystemModal(NSTouchBar *touchBar) {
    TBInvokeBar(touchBar, @"dismissSystemModalTouchBar:");
    TBInvokeBar(touchBar, @"dismissSystemModalFunctionBar:");
}

void TBMinimizeSystemModal(NSTouchBar *touchBar) {
    TBInvokeBar(touchBar, @"minimizeSystemModalTouchBar:");
    TBInvokeBar(touchBar, @"minimizeSystemModalFunctionBar:");
}

#pragma mark - Control Strip tray items

void TBAddSystemTrayItem(NSTouchBarItem *item) {
    SEL sel = NSSelectorFromString(@"addSystemTrayItem:");
    Method method = class_getClassMethod([NSTouchBarItem class], sel);
    if (!method) return;
    typedef void (*Fn)(id, SEL, NSTouchBarItem *);
    ((Fn)method_getImplementation(method))([NSTouchBarItem class], sel, item);
}

void TBRemoveSystemTrayItem(NSTouchBarItem *item) {
    SEL sel = NSSelectorFromString(@"removeSystemTrayItem:");
    Method method = class_getClassMethod([NSTouchBarItem class], sel);
    if (!method) return;
    typedef void (*Fn)(id, SEL, NSTouchBarItem *);
    ((Fn)method_getImplementation(method))([NSTouchBarItem class], sel, item);
}

#pragma mark - DFRFoundation (symbols loaded at runtime)

static void *TBDFRHandle(void) {
    static void *handle;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY);
    });
    return handle;
}

void TBSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present) {
    void *handle = TBDFRHandle();
    if (!handle) return;
    typedef void (*Fn)(NSTouchBarItemIdentifier, BOOL);
    Fn fn = (Fn)dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier");
    if (fn) fn(identifier, present);
}

void TBSetShowsCloseBoxWhenFrontMost(BOOL show) {
    void *handle = TBDFRHandle();
    if (!handle) return;
    typedef void (*Fn)(BOOL);
    Fn fn = (Fn)dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost");
    if (fn) fn(show);
}
