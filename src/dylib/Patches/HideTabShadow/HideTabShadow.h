// Shared by the selected tab's shadow and its border, which only changes once the shadow has gone.
#import "StdPatch/StdPatch.h"

extern DPPatch DPHideTabShadow, DPSubtleTabBorder;
extern NSHashTable<NSView *> *DPTabShapes;  // Every selected-tab shape Dia showed.

NSArray *DPOwnLayers(NSView *view, Class cls);  // Sublayers of that class that no subview owns.
void DPRestyleTabBorder(NSView *shape);
void DPRestyleTabShapes(DPPatch *patch);
