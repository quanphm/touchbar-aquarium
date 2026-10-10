#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Presents `touchBar` as a system-modal bar that stays visible while other
/// apps are frontmost. `placement` 1 targets the main (app) region.
/// Returns NO if the private API is unavailable on this OS.
BOOL TBPresentSystemModal(NSTouchBar *touchBar, long long placement, NSTouchBarItemIdentifier identifier);

/// Removes a previously presented system-modal bar.
void TBDismissSystemModal(NSTouchBar *touchBar);

/// Minimizes (rather than fully dismisses) a system-modal bar.
void TBMinimizeSystemModal(NSTouchBar *touchBar);

/// Registers / unregisters an item in the Control Strip on the right.
void TBAddSystemTrayItem(NSTouchBarItem *item);
void TBRemoveSystemTrayItem(NSTouchBarItem *item);

/// Hides the close box that appears when the owning app is frontmost.
void TBSetShowsCloseBoxWhenFrontMost(BOOL show);

/// Enables / disables Control Strip presence for an identifier.
void TBSetControlStripPresence(NSTouchBarItemIdentifier identifier, BOOL present);

NS_ASSUME_NONNULL_END
