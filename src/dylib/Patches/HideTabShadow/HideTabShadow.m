#import "HideTabShadow.h"

NSHashTable<NSView *> *DPTabShapes;
static char DPShadowKey;

NSArray *DPOwnLayers(NSView *view, Class cls) {
    NSMutableArray *layers = [NSMutableArray new];
    NSArray *viewLayers = [view.subviews valueForKey:@"layer"];
    for (CALayer *layer in view.layer.sublayers)
        if ([layer isKindOfClass:cls] && ![viewLayers containsObject:layer]) [layers addObject:layer];
    return layers;
}

// The selected tab's shape draws its shadow from a layer of its own, beside the layers of its subviews.
static void DPRestyleTabShape(NSView *shape) {
    for (CALayer *layer in DPOwnLayers(shape, CAShapeLayer.class)) {
        NSNumber *dia = DPDiaValue(layer, &DPShadowKey, @(layer.shadowOpacity));
        NSNumber *ours = DPHideTabShadow.on ? @0 : dia;
        DPOverride(layer, &DPShadowKey, dia, ours);
        if (layer.shadowOpacity != ours.floatValue) layer.shadowOpacity = ours.floatValue;
    }
    DPRestyleTabBorder(shape);
}

static void DPTabShape_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTabShape_layout, self);
    [DPTabShapes addObject:self];
    DPRestyleTabShape(self);
}

// Selecting a tab shows its shape without laying it out again.
static void DPTabShape_setHidden(NSView *self, SEL _cmd, BOOL hidden) {
    DPCallOriginal(DPTabShape_setHidden, self, hidden);
    [DPTabShapes addObject:self];
    DPRestyleTabShape(self);
}

static void DPInstallHideTabShadow(void) {
    DPTabShapes = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaTabShape, @selector(layout), (IMP)DPTabShape_layout);
    DPHook(DPDiaTabShape, @selector(setHidden:), (IMP)DPTabShape_setHidden);
}

void DPRestyleTabShapes(DPPatch *patch) {
    for (NSView *shape in DPFindViews(DPDiaTabShape)) [DPTabShapes addObject:shape];
    for (NSView *shape in DPTabShapes) DPRestyleTabShape(shape);
}

static NSString *DPVerifyHideTabShadow(DPPatch *patch) {
    BOOL found = NO;
    for (NSView *shape in DPFindViews(DPDiaTabShape)) {
        if (shape.hiddenOrHasHiddenAncestor) continue;
        for (CALayer *layer in DPOwnLayers(shape, CAShapeLayer.class)) {
            found = YES;
            if (patch->on && layer.shadowOpacity > 0) return @"selected tab still has a shadow";
            if (!patch->on && layer.shadowOpacity == 0) return @"selected tab lost Dia's shadow";
        }
    }
    return found ? nil : @"no selected tab found";
}

DP_PATCH(DPHideTabShadow) {
    .key = @"hideTabShadow",
    .order = 90,
    .title = @"Hide selected tab shadow",
    .detail = @"Remove the shadow around the selected tab.",
    .symbol = @"shadow",
    .tint = @"systemIndigoColor",
    .section = @"Sidebar and tab bar",
    .classes = DPClasses(DPDiaTabShape),
    .install = DPInstallHideTabShadow,
    .apply = DPRestyleTabShapes,
    .verify = DPVerifyHideTabShadow,
};
