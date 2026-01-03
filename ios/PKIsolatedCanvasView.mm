#import "PKIsolatedCanvasView.h"

@implementation PKIsolatedCanvasView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _isolatedUndoManager = [NSUndoManager new];
    _isolatedUndoManager.levelsOfUndo = 128;

    // Prevent iOS from automatically scrolling to top
    self.scrollsToTop = NO;

    // Prevent iOS from adjusting content insets automatically
    if (@available(iOS 11.0, *)) {
      self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
  }
  return self;
}

- (NSUndoManager*)undoManager {
  return _isolatedUndoManager;
}

- (BOOL)resignFirstResponder {
  CGPoint savedOffset = self.contentOffset;
  BOOL result = [super resignFirstResponder];
  // Restore scroll position on next run loop to override any automatic scrolling
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setContentOffset:savedOffset animated:NO];
  });
  return result;
}

@end
