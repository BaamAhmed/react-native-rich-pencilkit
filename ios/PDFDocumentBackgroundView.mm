#import "PDFDocumentBackgroundView.h"

@implementation NoFadeTiledLayer
+ (CFTimeInterval)fadeDuration {
  return 0.0;
}
@end

@implementation PDFDocumentBackgroundView

+ (Class)layerClass {
  return [NoFadeTiledLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame pdfPath:(NSString*)pdfPath {
  if (self = [super initWithFrame:frame]) {
    _zoomScale = 1.0;

    // Check if pdfPath is valid before creating NSURL
    if (pdfPath && pdfPath.length > 0) {
      NSURL* pdfURL = [NSURL fileURLWithPath:pdfPath];
      _document = [[PDFDocument alloc] initWithURL:pdfURL];

      if (_document) {
        [self calculateLayout];
      }
    }

    CATiledLayer* tiledLayer = (CATiledLayer*)self.layer;
    tiledLayer.tileSize = CGSizeMake(1024, 1024);
    tiledLayer.levelsOfDetail = 1;
  }
  return self;
}

- (void)calculateLayout {
  NSMutableArray* offsets = [NSMutableArray array];
  CGFloat yOffset = 0;
  CGFloat maxWidth = 0;

  for (NSInteger i = 0; i < _document.pageCount; i++) {
    PDFPage* page = [_document pageAtIndex:i];
    CGRect bounds = [page boundsForBox:kPDFDisplayBoxMediaBox];

    [offsets addObject:@(yOffset)];
    yOffset += bounds.size.height;
    maxWidth = MAX(maxWidth, bounds.size.width);
  }

  _pageYOffsets = [offsets copy];
  _totalHeight = yOffset;
  _pageWidth = maxWidth;
}

- (void)drawRect:(CGRect)rect {
  if (!_document || _pageWidth <= 0)
    return;

  CGContextRef context = UIGraphicsGetCurrentContext();

  // Fill background white
  [[UIColor whiteColor] setFill];
  UIRectFill(rect);

  // Scale PDF to fit the view's width (not by zoomScale - scroll view handles that)
  CGFloat fitScale = self.bounds.size.width / _pageWidth;

  // Find which pages intersect this rect and draw them
  for (NSInteger i = 0; i < _document.pageCount; i++) {
    CGFloat pageY = [_pageYOffsets[i] floatValue];
    PDFPage* page = [_document pageAtIndex:i];
    CGRect pageBounds = [page boundsForBox:kPDFDisplayBoxMediaBox];

    // Page frame in scaled coordinates
    CGRect pageFrame = CGRectMake(0, pageY * fitScale, pageBounds.size.width * fitScale,
                                  pageBounds.size.height * fitScale);

    // Skip pages that don't intersect the dirty rect
    if (!CGRectIntersectsRect(rect, pageFrame)) {
      continue;
    }

    // Draw this page
    CGContextSaveGState(context);

    // Scale to fit width, flip coordinate system for PDF drawing
    CGContextScaleCTM(context, fitScale, fitScale);
    CGContextTranslateCTM(context, 0, pageY + pageBounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    [page drawWithBox:kPDFDisplayBoxMediaBox toContext:context];

    CGContextRestoreGState(context);
  }
}

@end
