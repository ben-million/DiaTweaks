// Shared by the selected tab's shadow and its border, which only goes once the shadow has.
#import "StdPatch/StdPatch.h"

extern DPPatch DPHideTabShadow, DPHideTabBorder;
extern NSHashTable<NSView *> *DPTabShapes;  // Every selected-tab shape Dia showed.

NSArray *DPOwnLayers(NSView *view, Class cls);  // Sublayers of that class that no subview owns.
void DPRestyleTabBorder(NSView *shape);
void DPRestyleTabShapes(DPPatch *patch);
