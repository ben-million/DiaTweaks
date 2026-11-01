#import "HideTabShadow.h"

static char DPColorsKey;
static const CGFloat DPSubtleness = 0.2;  // Of Dia's strongest border color's alpha.

// The border is a gradient behind the tab, masked to a 1pt outline, that fades from the ends to nothing in the middle.
static NSArray<CAGradientLayer *> *DPBorderGradients(NSView *shape) {
    NSMutableArray *gradients = [NSMutableArray new];
    for (NSView *sub in shape.subviews)
        for (CAGradientLayer *layer in DPOwnLayers(sub, CAGradientLayer.class))
            if (layer.mask && layer.colors.count > 1) [gradients addObject:layer];
    return gradients;
}

static BOOL DPSolid(NSArray *colors) {
    for (id color in colors)
        if (!CGColorEqualToColor((__bridge CGColorRef)color, (__bridge CGColorRef)colors.firstObject)) return NO;
    return YES;
}

// Dia's strongest color, faint and the same all the way round.
static NSArray *DPSubtleColors(NSArray *colors) {
    CGColorRef strongest = (__bridge CGColorRef)colors.firstObject;
    for (id color in colors)
        if (CGColorGetAlpha((__bridge CGColorRef)color) > CGColorGetAlpha(strongest)) strongest = (__bridge CGColorRef)color;
    id subtle = CFBridgingRelease(CGColorCreateCopyWithAlpha(strongest, CGColorGetAlpha(strongest) * DPSubtleness));
    NSMutableArray *solid = [NSMutableArray new];
    for (NSUInteger i = 0; i < colors.count; i++) [solid addObject:subtle];
    return solid;
}

void DPRestyleTabBorder(NSView *shape) {
    for (CAGradientLayer *layer in DPBorderGradients(shape)) {
        NSArray *dia = DPDiaValue(layer, &DPColorsKey, layer.colors);
        NSArray *ours = DPSubtleTabBorder.on && DPHideTabShadow.on ? DPSubtleColors(dia) : dia;
        DPOverride(layer, &DPColorsKey, dia, ours);
        if (![layer.colors isEqual:ours]) layer.colors = ours;
    }
}

static NSString *DPVerifySubtleTabBorder(DPPatch *patch) {
    BOOL subtle = patch->on && DPHideTabShadow.on;
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        if (shape.hiddenOrHasHiddenAncestor) continue;
        for (CAGradientLayer *layer in DPBorderGradients(shape)) {
            NSArray *dia = DPDiaValue(layer, &DPColorsKey, layer.colors);
            if (subtle && !DPSolid(layer.colors)) return @"selected tab's border still fades";
            if (subtle && ![layer.colors isEqual:DPSubtleColors(dia)]) return @"selected tab's border isn't subtle";
            if (!subtle && ![layer.colors isEqual:dia]) return @"selected tab lost Dia's border";
        }
    }
    return nil;
}

DP_PATCH(DPSubtleTabBorder) {
    .key = @"subtleTabBorder",
    .order = 100,
    .title = @"Subtle border",
    .detail = @"Draw the selected tab's border faintly, in one even color instead of fading it.",
    .symbol = @"square",
    .tint = @"systemIndigoColor",
    .requires = @"hideTabShadow",
    .apply = DPRestyleTabShapes,
    .verify = DPVerifySubtleTabBorder,
};
