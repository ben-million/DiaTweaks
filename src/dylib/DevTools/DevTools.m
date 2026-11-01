#import "DevTools/DevTools.h"
#import "Updates/Updates.h"
#include <dlfcn.h>

static NSString *DPDescribeColor(CGColorRef color) {
    NSColor *rgb = [[NSColor colorWithCGColor:color] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return rgb ? [NSString stringWithFormat:@"%.2f,%.2f,%.2f,%.2f", rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent] : @"?";
}

// What a layer draws around and behind its content: shadow, border, stroke and gradient.
static void DPDescribeShadow(CALayer *layer, NSMutableString *out) {
    if (layer.shadowOpacity > 0)
        [out appendFormat:@" shadow=%g/%g%@", layer.shadowOpacity, layer.shadowRadius, NSStringFromSize(layer.shadowOffset)];
    if (layer.borderWidth > 0) [out appendFormat:@" border=%g(%@)", layer.borderWidth, DPDescribeColor(layer.borderColor)];
    if (layer.mask) [out appendFormat:@" mask=%@", NSStringFromClass(layer.mask.class)];
    if ([layer.mask isKindOfClass:CAShapeLayer.class]) {
        CAShapeLayer *mask = (CAShapeLayer *)layer.mask;
        [out appendFormat:@"(line=%g fill=%@)", mask.lineWidth, mask.fillColor ? DPDescribeColor(mask.fillColor) : @"none"];
    }
    if (layer.opacity < 1) [out appendFormat:@" opacity=%g", layer.opacity];
    if ([layer isKindOfClass:CAShapeLayer.class]) {
        CAShapeLayer *shape = (CAShapeLayer *)layer;
        if (shape.strokeColor && shape.lineWidth > 0) [out appendFormat:@" stroke=%g(%@)", shape.lineWidth, DPDescribeColor(shape.strokeColor)];
        if (shape.fillColor) [out appendFormat:@" fill=(%@)", DPDescribeColor(shape.fillColor)];
    }
    if ([layer isKindOfClass:CAGradientLayer.class]) {
        NSMutableArray *colors = [NSMutableArray new];
        for (id color in ((CAGradientLayer *)layer).colors) [colors addObject:DPDescribeColor((__bridge CGColorRef)color)];
        if (colors.count) [out appendFormat:@" gradient=[%@]", [colors componentsJoinedByString:@" "]];
    }
}

// Layers no view owns, such as a selection's shadow, which the views alone wouldn't show.
static void DPDescribeLayers(CALayer *layer, NSSet *viewLayers, NSUInteger depth, NSMutableString *out) {
    for (CALayer *sub in layer.sublayers) {
        if ([viewLayers containsObject:sub]) continue;
        [out appendFormat:@"%*s(layer) %@ %@", (int)depth * 2, "", NSStringFromClass(sub.class), NSStringFromRect(sub.frame)];
        if (sub.cornerRadius > 0) [out appendFormat:@" radius=%g", sub.cornerRadius];
        DPDescribeShadow(sub, out);
        if (sub.hidden) [out appendString:@" hidden"];
        [out appendString:@"\n"];
        DPDescribeLayers(sub, viewLayers, depth + 1, out);
    }
}

static void DPDescribe(NSView *view, NSUInteger depth, NSMutableString *out) {
    NSString *label = view.accessibilityLabel;
    [out appendFormat:@"%*s%@ %@", (int)depth * 2, "", NSStringFromClass(view.class), NSStringFromRect(view.frame)];
    if (label.length) [out appendFormat:@" label=\"%@\"", label];
    if (view.layer.cornerRadius > 0)
        [out appendFormat:@" radius=%g corners=%lu", view.layer.cornerRadius, (unsigned long)view.layer.maskedCorners];
    DPDescribeShadow(view.layer, out);
    if (view.hidden) [out appendString:@" hidden"];
    [out appendString:@"\n"];
    NSMutableSet *viewLayers = [NSMutableSet set];
    for (NSView *sub in view.subviews) if (sub.layer) [viewLayers addObject:sub.layer];
    if (view.layer) DPDescribeLayers(view.layer, viewLayers, depth + 1, out);
    for (NSView *sub in view.subviews) DPDescribe(sub, depth + 1, out);
}

NSString *DPDescribeViews(NSView *root) {
    NSMutableString *out = [NSMutableString new];
    if (root) DPDescribe(root, 0, out);
    return out;
}

// Copies the front window's view tree, titlebar included, for finding the classes and labels a patch can match.
static void DPCopyViewTree(void) {
    NSWindow *window = NSApp.keyWindow ?: NSApp.orderedWindows.firstObject;
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:DPDescribeViews(window.contentView.superview) forType:NSPasteboardTypeString];
}

// Lets a script toggle patches and read the result without touching the screen:
//     com.diapatches.dev.set, object "hideToolbar=1"   toggles a patch the way its switch does.
//     com.diapatches.dev.dump                          writes every window's view tree to views.txt beside the dylib.
static void DPListenForScripts(void) {
    NSDistributedNotificationCenter *center = NSDistributedNotificationCenter.defaultCenter;
    [center addObserverForName:@"com.diapatches.dev.set" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
        NSArray<NSString *> *parts = [note.object componentsSeparatedByString:@"="];
        DPPatch *patch = parts.count == 2 ? DPPatchNamed(parts[0]) : NULL;
        if (patch) DPSetPatch(patch, parts[1].boolValue, YES);
    }];
    [center addObserverForName:@"com.diapatches.dev.dump" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *_) {
        NSMutableString *out = [NSMutableString new];
        for (NSWindow *window in NSApp.windows)
            [out appendFormat:@"== window \"%@\"\n%@", window.title, DPDescribeViews(window.contentView.superview)];
        Dl_info dylib;
        dladdr((const void *)DPInstallDevTools, &dylib);
        NSString *path = [@(dylib.dli_fname).stringByDeletingLastPathComponent stringByAppendingPathComponent:@"views.txt"];
        [out writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }];
}

void DPInstallDevTools(void) {
    if (![[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] boolForKey:@"devTools"]) return;
    DPListenForScripts();
    DPOnLaunch(^{
        DPAddMenuItem(@"Help", @"DiaPatches: Copy View Tree", ^{ DPCopyViewTree(); });
        NSMenu *debug = [[NSMenu alloc] initWithTitle:@"Debug"];
        [debug addItem:DPMenuItem(@"Pretend Dia Has an Update", ^{ [DPUpdates.shared pretend:DPDia]; })];
        [debug addItem:DPMenuItem(@"Pretend DiaTweaks Has an Update", ^{ [DPUpdates.shared pretend:DPTweaks]; })];
        [debug addItem:DPMenuItem(@"Stop Pretending", ^{ [DPUpdates.shared stopPretending]; })];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Debug" action:nil keyEquivalent:@""];
        item.submenu = debug;
        [NSApp.mainMenu insertItem:item atIndex:1];
    });
}
