#import <PDFKit/PDFKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NoFadeTiledLayer : CATiledLayer
@end

@interface PDFDocumentBackgroundView : UIView
@property(nonatomic, strong) PDFDocument* document;
@property(nonatomic, assign) CGFloat zoomScale;
@property(nonatomic, assign) CGFloat totalHeight;
@property(nonatomic, assign) CGFloat pageWidth;
@property(nonatomic, strong) NSArray<NSNumber*>* pageYOffsets;
- (instancetype)initWithFrame:(CGRect)frame pdfPath:(NSString* _Nullable)pdfPath;
@end

NS_ASSUME_NONNULL_END
