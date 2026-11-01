#import "HideTabShadow.h"

static char DPColorsKey;

// The border is a gradient behind the tab, masked to a 1pt outline.
static NSArray<CAGradientLayer *> *DPBorderGradients(NSView *shape) {
    NSMutableArray *gradients = [NSMutableArray new];
    for (NSView *sub in shape.subviews)
        for (CAGradientLayer *layer in DPOwnLayers(sub, CAGradientLayer.class))
            if (layer.mask && layer.colors.count > 1) [gradients addObject:layer];
    return gradients;
}

static BOOL DPClear(NSArray *colors) {
    for (id color in colors) if (CGColorGetAlpha((__bridge CGColorRef)color) > 0) return NO;
    return YES;
}

static NSArray *DPClearColors(NSArray *colors) {
    NSMutableArray *clear = [NSMutableArray new];
    for (id color in colors) [clear addObject:CFBridgingRelease(CGColorCreateCopyWithAlpha((__bridge CGColorRef)color, 0))];
    return clear;
}

void DPRestyleTabBorder(NSView *shape) {
    for (CAGradientLayer *layer in DPBorderGradients(shape)) {
        NSArray *dia = DPDiaValue(layer, &DPColorsKey, layer.colors);
        NSArray *ours = DPHideTabBorder.on && DPHideTabShadow.on ? DPClearColors(dia) : dia;
        DPOverride(layer, &DPColorsKey, dia, ours);
        if (![layer.colors isEqual:ours]) layer.colors = ours;
    }
}

static NSString *DPVerifyHideTabBorder(DPPatch *patch) {
    BOOL hidden = patch->on && DPHideTabShadow.on;
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        if (shape.hiddenOrHasHiddenAncestor) continue;
        for (CAGradientLayer *layer in DPBorderGradients(shape)) {
            if (hidden && !DPClear(layer.colors)) return @"selected tab still has a border";
            if (!hidden && ![layer.colors isEqual:DPDiaValue(layer, &DPColorsKey, layer.colors)]) return @"selected tab lost Dia's border";
        }
    }
    return nil;
}

DP_PATCH(DPHideTabBorder) {
    .key = @"hideTabBorder",
    .order = 100,
    .title = @"Hide border",
    .detail = @"Remove the thin border around the selected tab too.",
    .symbol = @"square.dashed",
    .tint = @"systemIndigoColor",
    .requires = @"hideTabShadow",
    .apply = DPRestyleTabShapes,
    .verify = DPVerifyHideTabBorder,
};
