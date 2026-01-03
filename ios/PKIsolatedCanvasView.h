#import <PencilKit/PencilKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PKIsolatedCanvasView : PKCanvasView
@property(nonatomic, strong) NSUndoManager* isolatedUndoManager;
@end

NS_ASSUME_NONNULL_END
