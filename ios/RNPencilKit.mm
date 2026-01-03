#import "RNPencilKit.h"
#import <React/RCTLog.h>

#import <react/renderer/components/RNPencilKitSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNPencilKitSpec/EventEmitters.h>
#import <react/renderer/components/RNPencilKitSpec/Props.h>
#import <react/renderer/components/RNPencilKitSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"
#import <PDFKit/PDFKit.h>

#import "PDFDocumentBackgroundView.h"
#import "PKIsolatedCanvasView.h"
#import "PaperTemplateView.h"

using namespace facebook::react;

static inline const std::shared_ptr<const RNPencilKitEventEmitter>
getEmitter(const SharedViewEventEmitter emitter) {
  return std::static_pointer_cast<const RNPencilKitEventEmitter>(emitter);
}

// Helper function to convert RNPencilKitPaperTemplate to PaperTemplateType
static inline PaperTemplateType toPaperTemplateType(RNPencilKitPaperTemplate template_) {
  switch (template_) {
    case RNPencilKitPaperTemplate::Lined:
      return PaperTemplateTypeLined;
    case RNPencilKitPaperTemplate::Dotted:
      return PaperTemplateTypeDotted;
    case RNPencilKitPaperTemplate::Grid:
      return PaperTemplateTypeGrid;
    case RNPencilKitPaperTemplate::Blank:
    default:
      return PaperTemplateTypeBlank;
  }
}

@interface RNPencilKit () <RCTRNPencilKitViewProtocol, PKCanvasViewDelegate, PKToolPickerObserver,
                           UIPencilInteractionDelegate, UIScrollViewDelegate>

@end

@implementation RNPencilKit {
  PKCanvasView* _Nonnull _view;
  PKToolPicker* _Nullable _toolPicker;
  UILabel* _Nullable _boundsLabel;
  UIEdgeInsets _lastEdgeInsets;
  BOOL _allowInfiniteScroll;
  UILabel* _Nullable _debugLabel;
  RNPencilKitInfiniteScrollDirection _infScrollDir;
  RNPencilKitPaperTemplate _paperTemplate;
  BOOL _showDebugInfo;
  CADisplayLink* _Nullable _displayLink;
  UIImageView* _Nullable _backgroundImageView;
  PaperTemplateView* _Nullable _paperTemplateView;
  PDFDocumentBackgroundView* _Nullable _pdfBackgroundView;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNPencilKitProps>();
    _props = defaultProps;
    _view = [[PKIsolatedCanvasView alloc] initWithFrame:frame];
    _view.backgroundColor = [UIColor clearColor];
    _view.bouncesZoom = NO;

    _view.delegate = self;
    _toolPicker = [[PKToolPicker alloc] init];
    [_toolPicker addObserver:_view];
    [_toolPicker addObserver:self];
    [_toolPicker setVisible:YES forFirstResponder:_view];
    // Set default tool to monoline black pen with width 1
    if (@available(iOS 17.0, *)) {
      PKInkingTool* defaultTool = [[PKInkingTool alloc] initWithInkType:PKInkTypeMonoline
                                                                  color:[UIColor blackColor]
                                                                  width:1.5];
      _view.tool = defaultTool;
      _toolPicker.selectedTool = defaultTool;
    } else {
      // Fallback to regular pen for iOS < 17.0
      PKInkingTool* defaultTool = [[PKInkingTool alloc] initWithInkType:PKInkTypePen
                                                                  color:[UIColor blackColor]
                                                                  width:1.5];
      _view.tool = defaultTool;
      _toolPicker.selectedTool = defaultTool;
    }

    // NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    // NSString* pdfPath = [bundle pathForResource:@"sample_final" ofType:@"pdf"];
    // [self setupPDFBackground:pdfPath];

    [self setupPaperTemplateWithType:_paperTemplate backgroundColor:[UIColor whiteColor]];
    // Setup background image before setting contentView
    // [self setupBackgroundImage];

    self.contentView = _view;

    // ── Register for Pencil double-tap (2nd-gen Pencil or Apple Pencil Pro) ──
    if (@available(iOS 12.1, *)) {
      UIPencilInteraction* pencilInteraction = [[UIPencilInteraction alloc] init];
      pencilInteraction.delegate = self;
      [_view addInteraction:pencilInteraction];
    }

    // Initialize debug label (hidden by default)
    [self setupDebugLabel];
  }

  return self;
}

- (void)dealloc {
  [_toolPicker removeObserver:_view];
  [_toolPicker removeObserver:self];
  [self stopDebugUpdates];
}

- (void)setupDebugLabel {
  _debugLabel = [[UILabel alloc] init];
  _debugLabel.numberOfLines = 0;
  _debugLabel.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
  _debugLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
  _debugLabel.textColor = [UIColor whiteColor];
  _debugLabel.layer.cornerRadius = 6;
  _debugLabel.layer.masksToBounds = YES;
  _debugLabel.textAlignment = NSTextAlignmentLeft;
  _debugLabel.hidden = YES;
  _debugLabel.userInteractionEnabled = NO;

  // Add padding
  _debugLabel.contentMode = UIViewContentModeTop;
  [self addSubview:_debugLabel];
}

- (void)setupPaperTemplateWithType:(RNPencilKitPaperTemplate)templateType
                   backgroundColor:(UIColor*)backgroundColor {
  // Remove the previous paperTemplateView if it exists
  if (_paperTemplateView) {
    [_paperTemplateView removeFromSuperview];
    _paperTemplateView = nil;
  }
  _paperTemplateView = [[PaperTemplateView alloc]
        initWithFrame:CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height)
         templateType:toPaperTemplateType(templateType)
      backgroundColor:backgroundColor];
  _paperTemplateView.userInteractionEnabled = NO;
  [_view addSubview:_paperTemplateView];
  [_view sendSubviewToBack:_paperTemplateView];
}

- (void)setupPDFBackground:(NSString*)pdfPath {

  if (_paperTemplateView) {
    [_paperTemplateView removeFromSuperview];
    _paperTemplateView = nil;
  }

  // Remove existing PDF view
  if (_pdfBackgroundView) {
    [_pdfBackgroundView removeFromSuperview];
    _pdfBackgroundView = nil;
  }

  if (!pdfPath || pdfPath.length == 0)
    return;

  PDFDocumentBackgroundView* pdfView = [[PDFDocumentBackgroundView alloc] initWithFrame:CGRectZero
                                                                                pdfPath:pdfPath];

  if (!pdfView.document)
    return;

  // Set PDF view frame to match content
  pdfView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
  pdfView.zoomScale = _view.zoomScale;
  pdfView.userInteractionEnabled = NO;

  _pdfBackgroundView = pdfView;
  [_view addSubview:_pdfBackgroundView];
  [_view sendSubviewToBack:_pdfBackgroundView];
}

- (void)startDebugUpdates {
  if (!_displayLink) {
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateDebugInfo)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
}

- (void)stopDebugUpdates {
  if (_displayLink) {
    [_displayLink invalidate];
    _displayLink = nil;
  }
}

- (void)updateDebugInfo {
  if (!_showDebugInfo || !_debugLabel) {
    return;
  }

  CGRect drawingBounds = _view.drawing.bounds;
  CGRect viewBounds = _view.bounds;
  CGFloat zoomScale = _view.zoomScale;
  UIEdgeInsets contentInset = _view.contentInset;
  CGPoint contentOffset = _view.contentOffset;
  CGSize contentSize = _view.contentSize;

  // Calculate scaled drawing bounds
  CGRect scaledDrawingBounds =
      CGRectMake(drawingBounds.origin.x * zoomScale, drawingBounds.origin.y * zoomScale,
                 drawingBounds.size.width * zoomScale, drawingBounds.size.height * zoomScale);

  // Visible region calculation
  CGPoint visibleOrigin = CGPointMake(viewBounds.origin.x, viewBounds.origin.y);
  CGSize visibleSize = CGSizeMake(viewBounds.size.width, viewBounds.size.height);

  NSMutableString* debugText = [NSMutableString string];
  [debugText appendString:@"  DEBUG INFO  \n"];
  [debugText appendString:@"━━━━━━━━━━━━━\n"];

  // PDF Debug Info
  [debugText appendString:@"── PDF Background ──\n"];
  if (_pdfBackgroundView) {
    [debugText appendFormat:@"View: EXISTS\n"];
    [debugText appendFormat:@"Document: %@\n", _pdfBackgroundView.document ? @"LOADED" : @"NULL"];
    if (_pdfBackgroundView.document) {
      [debugText
          appendFormat:@"Pages: %lu\n", (unsigned long)_pdfBackgroundView.document.pageCount];
      [debugText appendFormat:@"PageWidth: %.1f\n", _pdfBackgroundView.pageWidth];
      [debugText appendFormat:@"TotalHeight: %.1f\n", _pdfBackgroundView.totalHeight];
    }
    CGRect pdfFrame = _pdfBackgroundView.frame;
    [debugText appendFormat:@"Frame: (%.1f,%.1f) %.1fx%.1f\n", pdfFrame.origin.x, pdfFrame.origin.y,
                            pdfFrame.size.width, pdfFrame.size.height];
    CGAffineTransform t = _pdfBackgroundView.transform;
    [debugText appendFormat:@"Transform: [%.2f,%.2f,%.2f,%.2f]\n", t.a, t.b, t.c, t.d];
    [debugText appendFormat:@"Hidden: %@\n", _pdfBackgroundView.hidden ? @"YES" : @"NO"];
    [debugText appendFormat:@"Alpha: %.2f\n", _pdfBackgroundView.alpha];
    [debugText appendFormat:@"Superview: %@\n", _pdfBackgroundView.superview ? @"YES" : @"NO"];
  } else {
    [debugText appendString:@"View: NULL\n"];
    // Check if PDF path exists
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    NSString* pdfPath = [bundle pathForResource:@"Transcript" ofType:@"pdf"];
    [debugText appendFormat:@"Path: %@\n", pdfPath ? @"FOUND" : @"NOT FOUND"];
    if (pdfPath) {
      [debugText appendFormat:@"  %@\n", [pdfPath lastPathComponent]];
    }
  }
  [debugText appendString:@"\n"];

  [debugText appendFormat:@"Zoom: %.2fx\n", zoomScale];
  [debugText appendFormat:@"MinZoom: %.2f MaxZoom: %.2f\n", _view.minimumZoomScale,
                          _view.maximumZoomScale];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"Content Offset:\n  (%.1f, %.1f)\n", contentOffset.x, contentOffset.y];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"View Bounds:\n  x:%.1f y:%.1f\n  w:%.1f h:%.1f\n", viewBounds.origin.x,
                          viewBounds.origin.y, viewBounds.size.width, viewBounds.size.height];
  [debugText appendString:@"\n"];
  [debugText
      appendFormat:@"Content Size:\n  w:%.1f h:%.1f\n", contentSize.width, contentSize.height];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"Content Inset:\n  t:%.1f l:%.1f\n  b:%.1f r:%.1f\n", contentInset.top,
                          contentInset.left, contentInset.bottom, contentInset.right];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"Drawing Bounds:\n  x:%.1f y:%.1f\n  w:%.1f h:%.1f\n",
                          drawingBounds.origin.x, drawingBounds.origin.y, drawingBounds.size.width,
                          drawingBounds.size.height];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"Scaled Drawing:\n  x:%.1f y:%.1f\n  w:%.1f h:%.1f\n",
                          scaledDrawingBounds.origin.x, scaledDrawingBounds.origin.y,
                          scaledDrawingBounds.size.width, scaledDrawingBounds.size.height];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"Visible Origin:\n  (%.1f, %.1f)\n", visibleOrigin.x, visibleOrigin.y];
  [debugText appendString:@"\n"];
  [debugText appendFormat:@"InfiniteScroll: %@\n", _allowInfiniteScroll ? @"YES" : @"NO"];
  NSString* scrollDirStr = @"bidirectional";
  if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical) {
    scrollDirStr = @"vertical";
  } else if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Horizontal) {
    scrollDirStr = @"horizontal";
  }
  [debugText appendFormat:@"ScrollDir: %@\n", scrollDirStr];

  _debugLabel.text = debugText;

  // Size the label to fit content with padding
  CGSize maxSize = CGSizeMake(220, CGFLOAT_MAX);
  CGSize textSize = [debugText boundingRectWithSize:maxSize
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName : _debugLabel.font}
                                            context:nil]
                        .size;

  CGFloat padding = 8;
  CGFloat labelWidth = textSize.width + padding * 2;
  CGFloat labelHeight = textSize.height + padding * 2;

  // Position in top right corner
  CGFloat xPos = self.bounds.size.width - labelWidth - 10;
  CGFloat yPos = 10;

  _debugLabel.frame = CGRectMake(xPos, yPos, labelWidth, labelHeight);

  // Add inner padding by adjusting text rect
  _debugLabel.textAlignment = NSTextAlignmentLeft;

  // Adjust attributed string for padding
  NSMutableParagraphStyle* paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.headIndent = padding;
  paragraphStyle.firstLineHeadIndent = padding;
  paragraphStyle.tailIndent = -padding;

  NSAttributedString* attributedText =
      [[NSAttributedString alloc] initWithString:debugText
                                      attributes:@{
                                        NSFontAttributeName : _debugLabel.font,
                                        NSForegroundColorAttributeName : _debugLabel.textColor,
                                        NSParagraphStyleAttributeName : paragraphStyle
                                      }];

  _debugLabel.attributedText = attributedText;
}

- (void)scrollViewWillBeginZooming:(UIScrollView*)scrollView withView:(UIView*)view {
  _lastEdgeInsets = _view.contentInset;
  if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Bidirectional)
    _view.contentInset = UIEdgeInsetsZero;
}

- (void)scrollViewDidEndZooming:(UIScrollView*)scrollView
                       withView:(UIView*)view
                        atScale:(CGFloat)scale {

  [self updateContentInset];

  if (_pdfBackgroundView) {
    _pdfBackgroundView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
    [_pdfBackgroundView.layer setNeedsDisplay];
  }

  // Force paper template to redraw completely after zoom ends
  // CATiledLayer caches tiles, so we need to clear and redraw
  if (_paperTemplateView) {
    _paperTemplateView.zoomScale = _view.zoomScale;
    _paperTemplateView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
    _paperTemplateView.layer.contents = nil;
    [_paperTemplateView.layer setNeedsDisplay];
  }
}

- (void)scrollViewDidZoom:(UIScrollView*)scrollView {
  // Update insets to match zoom level
  if (_allowInfiniteScroll && _infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical) {
    _view.contentInset = UIEdgeInsetsMake(_lastEdgeInsets.top / _view.zoomScale,
                                          _lastEdgeInsets.left / _view.zoomScale, 0,
                                          _lastEdgeInsets.right / _view.zoomScale);
  }
  if (_paperTemplateView) {
    _paperTemplateView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
  }

  if (_pdfBackgroundView) {
    _pdfBackgroundView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
    _pdfBackgroundView.zoomScale = _view.zoomScale;
  }

  // Update background image size to match zoom level
  if (_backgroundImageView) {
    CGFloat scale = _view.zoomScale;
    _backgroundImageView.frame = CGRectMake(0, 0, 20000 * scale, 20000 * scale);
  }
}

- (UIImage*)loadImageFromPath:(NSString*)imagePath {
  UIImage* image = nil;

  // Check if it's a base64 encoded image
  if ([imagePath hasPrefix:@"data:image/"]) {
    NSRange commaRange = [imagePath rangeOfString:@","];
    if (commaRange.location != NSNotFound) {
      NSString* base64String = [imagePath substringFromIndex:commaRange.location + 1];
      NSData* imageData =
          [[NSData alloc] initWithBase64EncodedString:base64String
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
      if (imageData) {
        image = [UIImage imageWithData:imageData];
      }
    }
  } else {
    // Try loading as a file path or resource name
    image = [UIImage imageNamed:imagePath];
    if (!image) {
      image = [UIImage imageWithContentsOfFile:imagePath];
    }
  }

  return image;
}

- (void)updateProps:(Props::Shared const&)props oldProps:(Props::Shared const&)oldProps {
  const auto& prev = *std::static_pointer_cast<RNPencilKitProps const>(_props);
  const auto& next = *std::static_pointer_cast<RNPencilKitProps const>(props);

  if (prev.alwaysBounceVertical ^ next.alwaysBounceVertical)
    _view.alwaysBounceVertical = next.alwaysBounceVertical;

  if (prev.alwaysBounceHorizontal ^ next.alwaysBounceHorizontal)
    _view.alwaysBounceHorizontal = next.alwaysBounceHorizontal;

  if (prev.drawingPolicy != next.drawingPolicy)
    _view.drawingPolicy = next.drawingPolicy == RNPencilKitDrawingPolicy::Anyinput
                              ? PKCanvasViewDrawingPolicyAnyInput
                          : next.drawingPolicy == RNPencilKitDrawingPolicy::Default
                              ? PKCanvasViewDrawingPolicyDefault
                              : PKCanvasViewDrawingPolicyPencilOnly;

  if (prev.isRulerActive ^ next.isRulerActive)
    [_view setRulerActive:next.isRulerActive];

  if (prev.isOpaque ^ next.isOpaque)
    [_view setOpaque:next.isOpaque];

  if (prev.backgroundColor ^ next.backgroundColor) {
    [self setupPaperTemplateWithType:_paperTemplate
                     backgroundColor:intToColor(next.backgroundColor)];
  }
  if (prev.infiniteScrollDirection != next.infiniteScrollDirection) {
    _infScrollDir = next.infiniteScrollDirection;
    [self applyContentSizeForInfiniteScroll];
    [self updateContentInset];
  }
  if (prev.allowInfiniteScroll ^ next.allowInfiniteScroll) {
    _allowInfiniteScroll = next.allowInfiniteScroll;
    [self applyContentSizeForInfiniteScroll];
    [self updateContentInset];
  }

  if (prev.minimumZoomScale != next.minimumZoomScale)
    _view.minimumZoomScale = next.minimumZoomScale;

  if (prev.maximumZoomScale != next.maximumZoomScale)
    _view.maximumZoomScale = next.maximumZoomScale;

  if (prev.showDebugInfo ^ next.showDebugInfo) {
    _showDebugInfo = next.showDebugInfo;
    _debugLabel.hidden = !next.showDebugInfo;

    if (next.showDebugInfo) {
      [self startDebugUpdates];
      [self updateDebugInfo];
    } else {
      [self stopDebugUpdates];
    }
  }

  if (prev.pdfPath != next.pdfPath) {
    if (next.pdfPath.empty()) {
      if (_pdfBackgroundView) {
        [_pdfBackgroundView removeFromSuperview];
        _pdfBackgroundView = nil;
      }
    } else {
      NSString* pdfPath = [NSString stringWithUTF8String:next.pdfPath.c_str()];
      [self setupPDFBackground:pdfPath];
    }
  }

  if (prev.paperTemplate != next.paperTemplate) {
    _paperTemplate = next.paperTemplate;
    [self setupPaperTemplateWithType:_paperTemplate
                     backgroundColor:intToColor(next.backgroundColor)];
  }

  [super updateProps:props oldProps:oldProps];
}

- (void)applyContentSizeForInfiniteScroll {
  _view.zoomScale = 1;
  CGFloat width = _view.bounds.size.width;
  CGFloat height = _view.bounds.size.height;

  // Don't set contentSize if bounds aren't valid yet - will be called again in layoutSubviews
  if (width <= 0 || height <= 0) {
    return;
  }

  CGSize newContentSize;
  if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Bidirectional) {
    newContentSize = CGSizeMake(20000, 20000);
  } else if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical) {
    newContentSize = CGSizeMake(width, 20000);
  } else if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Horizontal) {
    newContentSize = CGSizeMake(20000, height);
  } else {
    // Default fallback
    newContentSize = CGSizeMake(20000, 20000);
  }

  // Only update if the content size actually changed to avoid unnecessary updates
  if (!CGSizeEqualToSize(_view.contentSize, newContentSize)) {
    _view.contentSize = newContentSize;
    [self updateContentInset];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];

  if (_paperTemplateView) {
    _paperTemplateView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
  }

  // Update PDF background view frame on layout
  if (_pdfBackgroundView) {
    _pdfBackgroundView.frame = CGRectMake(0, 0, _view.contentSize.width, _view.contentSize.height);
  }

  if (_allowInfiniteScroll)
    [self applyContentSizeForInfiniteScroll];

  if (_showDebugInfo) {
    [self updateDebugInfo];
    // Ensure debug label stays on top
    [self bringSubviewToFront:_debugLabel];
  }
}

- (void)updateContentInset {
  // don't bother if the allowInfiniteScroll prop isn't set
  if (!_allowInfiniteScroll) {
    return;
  }

  const CGFloat z = MAX(_view.zoomScale, 0.0001);

  // Visible size in content coordinates
  const CGSize viewportInContent = _view.bounds.size;

  const CGPoint visibleOriginInContent = (CGPoint){_view.bounds.origin.x, _view.bounds.origin.y};

  const CGRect visible = (CGRect){visibleOriginInContent, viewportInContent};

  const CGRect drawing =
      (CGRect){.origin = (CGPoint){_view.drawing.bounds.origin.x * _view.zoomScale,
                                   _view.drawing.bounds.origin.y * _view.zoomScale},
               .size = (CGSize){_view.drawing.bounds.size.width * _view.zoomScale,
                                _view.drawing.bounds.size.height * _view.zoomScale}};

  // One-viewport padding (in content coordinates)
  const CGFloat padX = viewportInContent.width;
  const CGFloat padY = viewportInContent.height;

  // Expand bounds based on infinite scroll direction
  const CGRect expanded = _infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical
                              ? CGRectMake(drawing.origin.x, drawing.origin.y, drawing.size.width,
                                           drawing.size.height + padY)
                              : CGRectInset(drawing, -padX, -padY);

  // Include what's currently on screen (correctly measured)
  CGRect finalContentBounds = CGRectUnion(expanded, visible);

  // (Optional) Keep bounds inside contentSize to avoid pathological insets
  finalContentBounds.origin.x = MAX(0, finalContentBounds.origin.x);
  finalContentBounds.origin.y = MAX(0, finalContentBounds.origin.y);
  finalContentBounds.size.width =
      MIN(finalContentBounds.size.width, _view.contentSize.width - finalContentBounds.origin.x);
  finalContentBounds.size.height =
      MIN(finalContentBounds.size.height, _view.contentSize.height - finalContentBounds.origin.y);

  CGFloat horizontallyCenteringInset =
      finalContentBounds.size.width < viewportInContent.width
          ? ((viewportInContent.width - finalContentBounds.size.width) / 2.0)
          : 0;

  if (CGSizeEqualToSize(_view.drawing.bounds.size, CGSizeZero)) {
    if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical) {
      // if we want to scroll vertically, we must set negative insets on the bottom to allow
      // progressive unlocking, and a positive offset on the top to make the page appear below the
      // top edge of the screen
      _view.contentInset =
          (UIEdgeInsets){.top = -finalContentBounds.origin.y + (viewportInContent.height / 3.0),
                         .left = horizontallyCenteringInset,
                         .bottom = _view.contentSize.height - viewportInContent.height,
                         .right = horizontallyCenteringInset};

      _view.contentOffset = (CGPoint){.x = 0, .y = viewportInContent.height / 3.0};

    } else {
      // Center an empty canvas using viewportInContent, not raw bounds
      const CGFloat leftInset = (_view.contentSize.width - viewportInContent.width) / 2.0;
      const CGFloat topInset = (_view.contentSize.height - viewportInContent.height) / 2.0;

      _view.contentInset = (UIEdgeInsets){
          .top = -topInset,
          .left = -leftInset,
          .bottom = -topInset,
          .right = -leftInset,
      };
    }
    return;
  }

  if (_infScrollDir == RNPencilKitInfiniteScrollDirection::Vertical) {

    _view.contentInset = (UIEdgeInsets){
        .top = -finalContentBounds.origin.y + (viewportInContent.height / 3.0),
        .left = horizontallyCenteringInset,
        .bottom = -(_view.contentSize.height - CGRectGetMaxY(finalContentBounds)),
        .right = horizontallyCenteringInset,
    };
  } else {
    _view.contentInset = (UIEdgeInsets){
        .top = -finalContentBounds.origin.y,
        .left = -finalContentBounds.origin.x,
        .bottom = -(_view.contentSize.height - CGRectGetMaxY(finalContentBounds)),
        .right = -(_view.contentSize.width - CGRectGetMaxX(finalContentBounds)),
    };
  }
}

- (void)clearUndoStack {
  [_view.undoManager removeAllActions];
}

- (void)clear {
  [_view setDrawing:[[PKDrawing alloc] init]];
}

- (void)showToolPicker {
  [_view becomeFirstResponder];
}
- (void)hideToolPicker {
  [_view resignFirstResponder];
}
- (void)redo {
  [_view.undoManager redo];
}

- (void)undo {
  [_view.undoManager undo];
}

- (NSString*)getBase64Data {
  return [_view.drawing.dataRepresentation base64EncodedStringWithOptions:0];
}

- (NSDictionary*)getDrawingBounds {
  CGRect bounds = _view.drawing.bounds;
  return @{
    @"x" : @(bounds.origin.x),
    @"y" : @(bounds.origin.y),
    @"width" : @(bounds.size.width),
    @"height" : @(bounds.size.height)
  };
}

- (NSString*)getBase64PngData:(double)scale
                            x:(double)x
                            y:(double)y
                        width:(double)width
                       height:(double)height {
  NSData* data = _view.drawing.dataRepresentation;
  if (!data) {
    return nil;
  }

  CGRect rect;
  if (width > 0 && height > 0) {

    rect = CGRectMake((_view.bounds.origin.x + x) / _view.zoomScale,
                      (_view.bounds.origin.y + y) / _view.zoomScale, width / _view.zoomScale,
                      height / _view.zoomScale);
  } else {
    // Use the default bounds
    rect = CGRectMake(
        _view.bounds.origin.x / _view.zoomScale, _view.bounds.origin.y / _view.zoomScale,
        _view.bounds.size.width / _view.zoomScale, _view.bounds.size.height / _view.zoomScale);
  }

  UIImage* image = [_view.drawing imageFromRect:rect
                                          scale:scale == 0 ? UIScreen.mainScreen.scale : scale];
  NSData* imageData = UIImagePNGRepresentation(image);
  return [imageData base64EncodedStringWithOptions:0];
}

- (NSString*)getBase64JpegData:(double)scale compression:(double)compression {
  NSData* data = _view.drawing.dataRepresentation;
  if (!data) {
    return nil;
  }
  UIImage* image = [_view.drawing imageFromRect:_view.bounds
                                          scale:scale == 0 ? UIScreen.mainScreen.scale : scale];
  NSData* imageData = UIImageJPEGRepresentation(image, compression == 0 ? 0.93 : compression);
  return [imageData base64EncodedStringWithOptions:0];
}

- (NSString*)saveDrawing:(NSString*)path {
  NSData* data = [_view.drawing dataRepresentation];
  if (!data) {
    return nil;
  }
  NSError* error = nil;
  [data writeToURL:[[NSURL alloc] initFileURLWithPath:path]
           options:NSDataWritingAtomic
             error:&error];
  if (error) {
    return nil;
  } else {
    return [data base64EncodedStringWithOptions:0];
  }
}

- (BOOL)loadDrawing:(NSString*)path {
  NSURL* url = [[NSURL alloc] initFileURLWithPath:path];
  if (![[NSFileManager defaultManager] fileExistsAtPath:[url path]]) {
    return NO;
  }

  NSData* data = [[NSData alloc] initWithContentsOfURL:url];
  return [self loadWithData:data];
}

- (BOOL)loadBase64Data:(NSString*)base64 {
  NSData* data =
      [[NSData alloc] initWithBase64EncodedString:base64
                                          options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [self loadWithData:data];
}

- (BOOL)loadWithData:(NSData*)data {
  if (!data) {
    return NO;
  }
  NSError* error = nil;
  PKDrawing* drawing = [[PKDrawing alloc] initWithData:data error:&error];
  if (error || !drawing) {
    return NO;
  } else {
    PKCanvasView* newCanvas = [self copyCanvas:_view];
    [_view removeFromSuperview];
    _view = newCanvas;
    self.contentView = newCanvas;

    [_view.undoManager removeAllActions];
    [_view setDrawing:drawing];
    return YES;
  }
}

- (PKCanvasView*)copyCanvas:(PKCanvasView*)v {
  PKIsolatedCanvasView* newView = [[PKIsolatedCanvasView alloc] initWithFrame:v.frame];
  newView.alwaysBounceVertical = v.alwaysBounceVertical;
  newView.alwaysBounceHorizontal = v.alwaysBounceHorizontal;
  [newView setRulerActive:v.isRulerActive];
  [newView setBackgroundColor:v.backgroundColor];
  [newView setDrawingPolicy:v.drawingPolicy];
  [newView setOpaque:v.isOpaque];
  newView.contentSize =
      CGSizeMake(v.contentSize.width / v.zoomScale, v.contentSize.height / v.zoomScale);
  newView.contentInset = v.contentInset;
  newView.minimumZoomScale = v.minimumZoomScale;
  newView.maximumZoomScale = v.maximumZoomScale;
  newView.zoomScale = v.zoomScale;
  newView.bounds = v.bounds;
  newView.delegate = self;

  // Setup PDF background view for the new canvas
  if (_pdfBackgroundView) {
    PDFDocumentBackgroundView* oldPdfView = _pdfBackgroundView;
    PDFDocumentBackgroundView* newPdfBackgroundView = [[PDFDocumentBackgroundView alloc]
        initWithFrame:oldPdfView.frame
              pdfPath:nil]; // Document is already loaded, we'll copy it

    // Copy the document reference and layout properties
    newPdfBackgroundView.document = oldPdfView.document;
    newPdfBackgroundView.pageYOffsets = oldPdfView.pageYOffsets;
    newPdfBackgroundView.totalHeight = oldPdfView.totalHeight;
    newPdfBackgroundView.pageWidth = oldPdfView.pageWidth;
    newPdfBackgroundView.zoomScale = oldPdfView.zoomScale;
    newPdfBackgroundView.frame = oldPdfView.frame;
    newPdfBackgroundView.layer.anchorPoint = oldPdfView.layer.anchorPoint;
    newPdfBackgroundView.layer.position = oldPdfView.layer.position;
    newPdfBackgroundView.transform = oldPdfView.transform;
    newPdfBackgroundView.userInteractionEnabled = NO;

    [newView addSubview:newPdfBackgroundView];
    [newView sendSubviewToBack:newPdfBackgroundView];
    _pdfBackgroundView = newPdfBackgroundView;
  }

  // Setup paper template view for the new canvas
  if (_paperTemplateView) {
    PaperTemplateView* oldPaperView = _paperTemplateView;
    PaperTemplateView* newPaperTemplateView =
        [[PaperTemplateView alloc] initWithFrame:_paperTemplateView.frame
                                    templateType:oldPaperView.templateType
                                 backgroundColor:oldPaperView.paperBackgroundColor];
    newPaperTemplateView.userInteractionEnabled = NO;
    [newView addSubview:newPaperTemplateView];
    [newView sendSubviewToBack:newPaperTemplateView];
    _paperTemplateView = newPaperTemplateView;
  }

  // ── Copy Pencil double-tap interaction (2nd-gen Pencil or Apple Pencil Pro) ──
  if (@available(iOS 12.1, *)) {
    UIPencilInteraction* pencilInteraction = [[UIPencilInteraction alloc] init];
    pencilInteraction.delegate = self;
    [newView addInteraction:pencilInteraction];
  }

  [_toolPicker removeObserver:v];
  [_toolPicker addObserver:newView];
  [_toolPicker setVisible:true forFirstResponder:newView];
  if (_toolPicker.isVisible) {
    [newView becomeFirstResponder];
  }
  return newView;
}

- (void)setTool:(NSString*)toolType width:(double)width color:(NSInteger)color {
  std::string tool = [toolType UTF8String];
  BOOL isWidthValid = width != 0;
  BOOL isColorValid = color != 0;
  double defaultWidth = 1;
  UIColor* defaultColor = [UIColor blackColor];
  if (tool == "pen") {
    _toolPicker.selectedTool = _view.tool =
        [[PKInkingTool alloc] initWithInkType:PKInkTypePen
                                        color:isColorValid ? intToColor(color) : defaultColor
                                        width:isWidthValid ? width : defaultWidth];
  }
  if (tool == "pencil") {
    _toolPicker.selectedTool = _view.tool =
        [[PKInkingTool alloc] initWithInkType:PKInkTypePencil
                                        color:isColorValid ? intToColor(color) : defaultColor
                                        width:isWidthValid ? width : defaultWidth];
  }
  if (tool == "marker") {
    _toolPicker.selectedTool = _view.tool =
        [[PKInkingTool alloc] initWithInkType:PKInkTypeMarker
                                        color:isColorValid ? intToColor(color) : defaultColor
                                        width:isWidthValid ? width : defaultWidth];
  }
  if (@available(iOS 17.0, *)) {
    if (tool == "monoline") {
      _toolPicker.selectedTool = _view.tool =
          [[PKInkingTool alloc] initWithInkType:PKInkTypeMonoline
                                          color:isColorValid ? intToColor(color) : defaultColor
                                          width:isWidthValid ? width : defaultWidth];
    }
    if (tool == "fountainPen") {
      _toolPicker.selectedTool = _view.tool =
          [[PKInkingTool alloc] initWithInkType:PKInkTypeFountainPen
                                          color:isColorValid ? intToColor(color) : defaultColor
                                          width:isWidthValid ? width : defaultWidth];
    }
    if (tool == "watercolor") {
      _toolPicker.selectedTool = _view.tool =
          [[PKInkingTool alloc] initWithInkType:PKInkTypeWatercolor
                                          color:isColorValid ? intToColor(color) : defaultColor
                                          width:isWidthValid ? width : defaultWidth];
    }
    if (tool == "crayon") {
      _toolPicker.selectedTool = _view.tool =
          [[PKInkingTool alloc] initWithInkType:PKInkTypeCrayon
                                          color:isColorValid ? intToColor(color) : defaultColor
                                          width:isWidthValid ? width : defaultWidth];
    }
  }

  if (tool == "select") {
    _toolPicker.selectedTool = _view.tool = [[PKLassoTool alloc] init];
  }

  if (tool == "eraserVector") {
    if (@available(iOS 16.4, *)) {
      _toolPicker.selectedTool = _view.tool =
          [[PKEraserTool alloc] initWithEraserType:PKEraserTypeVector
                                             width:isWidthValid ? width : defaultWidth];
    } else {
      _toolPicker.selectedTool = _view.tool =
          [[PKEraserTool alloc] initWithEraserType:PKEraserTypeVector];
    }
  }
  if (tool == "eraserBitmap") {
    if (@available(iOS 16.4, *)) {
      _toolPicker.selectedTool = _view.tool =
          [[PKEraserTool alloc] initWithEraserType:PKEraserTypeBitmap
                                             width:isWidthValid ? width : defaultWidth];
    } else {
      _toolPicker.selectedTool = _view.tool =
          [[PKEraserTool alloc] initWithEraserType:PKEraserTypeBitmap];
    }
  }
  if (@available(iOS 16.4, *)) {
    if (tool == "eraserFixedWidthBitmap") {
      _toolPicker.selectedTool = _view.tool =
          [[PKEraserTool alloc] initWithEraserType:PKEraserTypeFixedWidthBitmap
                                             width:isWidthValid ? width : defaultWidth];
    }
  }
}

- (NSString*)getTool {
  PKTool* currentTool = _view.tool;
  if ([currentTool isKindOfClass:[PKInkingTool class]]) {
    PKInkingTool* inkingTool = (PKInkingTool*)currentTool;
    if (inkingTool.inkType == PKInkTypePen) {
      return @"pen";
    } else if (inkingTool.inkType == PKInkTypePencil) {
      return @"pencil";
    } else if (inkingTool.inkType == PKInkTypeMarker) {
      return @"marker";
    } else if (inkingTool.inkType == PKInkTypeFountainPen) {
      return @"fountainPen";
    } else if (inkingTool.inkType == PKInkTypeWatercolor) {
      return @"watercolor";
    } else if (inkingTool.inkType == PKInkTypeCrayon) {
      return @"crayon";
    }
  } else if ([currentTool isKindOfClass:[PKEraserTool class]]) {
    PKEraserTool* eraserTool = (PKEraserTool*)currentTool;
    if (eraserTool.eraserType == PKEraserTypeVector) {
      return @"eraserVector";
    } else if (eraserTool.eraserType == PKEraserTypeBitmap) {
      return @"eraserBitmap";
    } else if (@available(iOS 16.4, *)) {
      if (eraserTool.eraserType == PKEraserTypeFixedWidthBitmap) {
        return @"eraserFixedWidthBitmap";
      }
    }
  }
  return @"unknown";
}

@end

@implementation RNPencilKit (PKCanvasviewDelegate)
- (void)canvasViewDidBeginUsingTool:(PKCanvasView*)canvasView {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onCanvasViewDidBeginUsingTool({});
  }
}
- (void)canvasViewDrawingDidChange:(PKCanvasView*)canvasView {
  if (auto e = getEmitter(_eventEmitter)) {
    [self updateContentInset];
    e->onCanvasViewDrawingDidChange({});
  }
}
- (void)canvasViewDidEndUsingTool:(PKCanvasView*)canvasView {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onCanvasViewDidEndUsingTool({});
  }
}
- (void)canvasViewDidFinishRendering:(PKCanvasView*)canvasView {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onCanvasViewDidFinishRendering({});
  }
}
@end

@implementation RNPencilKit (PKToolPickerObserver)
- (void)toolPickerVisibilityDidChange:(PKToolPicker*)toolPicker {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onToolPickerVisibilityDidChange({});
  }
}
- (void)toolPickerSelectedToolDidChange:(PKToolPicker*)toolPicker {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onToolPickerSelectedToolDidChange({});
  }
}
- (void)toolPickerFramesObscuredDidChange:(PKToolPicker*)toolPicker {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onToolPickerFramesObscuredDidChange({});
  }
}
- (void)toolPickerIsRulerActiveDidChange:(PKToolPicker*)toolPicker {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onToolPickerIsRulerActiveDidChange({});
  }
}
@end

@implementation RNPencilKit (UIPencilInteractionDelegate)
- (void)pencilInteractionDidTap:(UIPencilInteraction*)interaction API_AVAILABLE(ios(12.1)) {
  if (auto e = getEmitter(_eventEmitter)) {
    e->onPencilDoubleTap({});
  }
}
@end

@implementation RNPencilKit (ReactNative)
- (void)handleCommand:(const NSString*)commandName args:(const NSArray*)args {
  RCTRNPencilKitHandleCommand(self, commandName, args);
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<RNPencilKitComponentDescriptor>();
}

Class<RCTComponentViewProtocol> RNPencilKitCls(void) {
  return RNPencilKit.class;
}

@end
