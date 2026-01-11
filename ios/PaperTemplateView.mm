#import "PaperTemplateView.h"

@implementation PaperTemplateView

+ (Class)layerClass {
  return [CATiledLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
                 templateType:(PaperTemplateType)templateType
              backgroundColor:(UIColor*)backgroundColor {
  if (self = [super initWithFrame:frame]) {
    _templateType = templateType;
    _paperBackgroundColor = backgroundColor ?: [UIColor clearColor];
    _zoomScale = 1.0;
    _baseWidth = 1200.0;
    _isInfiniteCanvas = NO;

    [_paperBackgroundColor setFill];
    UIRectFill(frame);

    CATiledLayer* tiledLayer = (CATiledLayer*)self.layer;
    tiledLayer.tileSize = CGSizeMake(512, 512);
    tiledLayer.levelsOfDetail = 1;
    tiledLayer.levelsOfDetailBias = 0;
  }
  return self;
}

- (void)drawLined:(CGRect)rect scale:(CGFloat)scale {
  CGFloat lineHeight = 36.0 * scale;
  CGFloat lineThickness = 2.0 * scale;
  CGFloat width = CGRectGetWidth(self.layer.bounds);

  [[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0] setFill];
  UIRectFill(rect);

  [[UIColor colorWithRed:0.85 green:0.85 blue:0.9 alpha:1.0] setFill];

  // Only draw lines that intersect the dirty rect
  CGFloat startY = floor(rect.origin.y / lineHeight) * lineHeight;
  CGFloat endY = CGRectGetMaxY(rect);

  for (CGFloat y = startY; y < endY; y += lineHeight) {
    CGRect lineRect = CGRectMake(0, y, width, lineThickness);
    UIRectFill(lineRect);
  }
}

- (void)drawDotted:(CGRect)rect scale:(CGFloat)scale {
  CGFloat dotSpacing = 36.0 * scale;
  CGFloat dotRadius = 2.0 * scale;

  [[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0] setFill];
  UIRectFill(rect);

  [[UIColor colorWithRed:0.85 green:0.85 blue:0.9 alpha:1.0] setFill];

  // Only draw dots that intersect the dirty rect
  CGFloat startX = floor(rect.origin.x / dotSpacing) * dotSpacing;
  CGFloat startY = floor(rect.origin.y / dotSpacing) * dotSpacing;
  CGFloat endX = CGRectGetMaxX(rect);
  CGFloat endY = CGRectGetMaxY(rect);

  for (CGFloat y = startY; y < endY; y += dotSpacing) {
    for (CGFloat x = startX; x < endX; x += dotSpacing) {
      CGRect dotRect = CGRectMake(x - dotRadius, y - dotRadius, dotRadius * 2, dotRadius * 2);
      UIBezierPath* dotPath = [UIBezierPath bezierPathWithOvalInRect:dotRect];
      [dotPath fill];
    }
  }
}

- (void)drawGrid:(CGRect)rect scale:(CGFloat)scale {
  CGFloat gridSpacing = 36.0 * scale;
  CGFloat lineThickness = 1.0 * scale;
  CGFloat width = CGRectGetWidth(self.layer.bounds);
  CGFloat height = CGRectGetHeight(self.layer.bounds);

  [[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0] setFill];
  UIRectFill(rect);

  [[UIColor colorWithRed:0.85 green:0.85 blue:0.9 alpha:1.0] setFill];

  // Draw horizontal lines that intersect the dirty rect
  CGFloat startY = floor(rect.origin.y / gridSpacing) * gridSpacing;
  CGFloat endY = CGRectGetMaxY(rect);

  for (CGFloat y = startY; y < endY; y += gridSpacing) {
    CGRect lineRect = CGRectMake(0, y, width, lineThickness);
    UIRectFill(lineRect);
  }

  // Draw vertical lines that intersect the dirty rect
  CGFloat startX = floor(rect.origin.x / gridSpacing) * gridSpacing;
  CGFloat endX = CGRectGetMaxX(rect);

  for (CGFloat x = startX; x < endX; x += gridSpacing) {
    CGRect lineRect = CGRectMake(x, 0, lineThickness, height);
    UIRectFill(lineRect);
  }
}

- (void)drawBorder:(CGRect)rect scale:(CGFloat)scale {
  CGFloat borderWidth = 3.0 * scale;
  UIColor* borderColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.85 alpha:1.0];

  [[UIColor whiteColor] setFill];
  UIRectFill(rect);

  [borderColor setStroke];
  UIBezierPath* borderPath =
      [UIBezierPath bezierPathWithRect:CGRectInset(self.bounds, borderWidth / 2, borderWidth / 2)];
  borderPath.lineWidth = borderWidth;
  [borderPath stroke];
}

- (void)drawRect:(CGRect)rect {
  CGFloat scale = _isInfiniteCanvas ? _zoomScale : self.frame.size.width / _baseWidth;

  [self drawBorder:rect scale:scale];

  // Draw template pattern based on type
  switch (_templateType) {
    case PaperTemplateTypeLined:
      [self drawLined:rect scale:scale];
      break;
    case PaperTemplateTypeDotted:
      [self drawDotted:rect scale:scale];
      break;
    case PaperTemplateTypeGrid:
      [self drawGrid:rect scale:scale];
      break;
    case PaperTemplateTypeBlank:
    default:
      // No pattern for blank
      break;
  }
}

@end
