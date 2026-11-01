#import <objc/message.h>
#import "StdPatch/StdPatch.h"

extern DPPatch DPKeepWindowsActive;

// AppKit asks a window's _hasActiveAppearance to pick its shadow and materials.
#define DPHasActiveAppearance @selector(_hasActiveAppearance)

static BOOL DPIsBrowserWindow(NSWindow *window) {
    return (window.styleMask & NSWindowStyleMaskTitled) && ![window isKindOfClass:NSPanel.class];
}

static BOOL DPWindow_hasActiveAppearance(NSWindow *self, SEL _cmd) {
    return (DPKeepWindowsActive.on && DPIsBrowserWindow(self)) || DPCallOriginal(DPWindow_hasActiveAppearance, self);
}

// DEBUG: Dia's window buttons follow hasKeyAppearance, so every window claims it. Focus rings and other key-only
// looks may then show in background windows too.
static BOOL DPWindow_hasKeyAppearance(NSWindow *self, SEL _cmd) {
    return (DPKeepWindowsActive.on && DPIsBrowserWindow(self)) || DPCallOriginal(DPWindow_hasKeyAppearance, self);
}

// Each view and the shadow only look again when focus changes, so tell them it did.
static void DPRefreshWindow(NSWindow *window) {
    ((void (*)(id, SEL))objc_msgSend)(window, @selector(_setShadowParameters));
    NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObject:window.contentView.superview];
    while (views.count) {
        NSView *view = views.lastObject;
        [views removeLastObject];
        [views addObjectsFromArray:view.subviews];
        if ([view respondsToSelector:@selector(_windowChangedKeyState)]) ((void (*)(id, SEL))objc_msgSend)(view, @selector(_windowChangedKeyState));
        view.needsDisplay = YES;
    }
}

static void DPApplyKeepWindowsActive(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows)
        if (DPIsBrowserWindow(window)) DPRefreshWindow(window);
}

static NSString *DPVerifyKeepWindowsActive(DPPatch *patch) {
    for (NSWindow *window in NSApp.windows) {
        if (!DPIsBrowserWindow(window) || !window.visible) continue;
        BOOL active = ((BOOL (*)(id, SEL))objc_msgSend)(window, DPHasActiveAppearance);
        if (patch->on && !active) return @"a window looks inactive";
        if (!patch->on && active && !window.isKeyWindow && !window.isMainWindow) return @"a background window looks active";
    }
    return nil;
}

static void DPInstallKeepWindowsActive(void) {
    DPHookClass(NSWindow.class, DPHasActiveAppearance, (IMP)DPWindow_hasActiveAppearance);
    DPHookClass(NSWindow.class, @selector(hasKeyAppearance), (IMP)DPWindow_hasKeyAppearance);
}

DP_PATCH(DPKeepWindowsActive) {
    .key = @"keepWindowsActive",
    .order = 90,
    .title = @"Keep windows active",
    .detail = @"Keep a window’s deep shadow and sidebar colour after you click into another app.",
    .symbol = @"macwindow",
    .tint = @"systemIndigoColor",
    .section = @"Window",
    .install = DPInstallKeepWindowsActive,
    .apply = DPApplyKeepWindowsActive,
    .verify = DPVerifyKeepWindowsActive,
};
