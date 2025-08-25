#import "RNPencilKit.h"
#import <React/RCTLog.h>

#import <react/renderer/components/RNPencilKitSpec/ComponentDescriptors.h>
#import <react/renderer/components/RNPencilKitSpec/EventEmitters.h>
#import <react/renderer/components/RNPencilKitSpec/Props.h>
#import <react/renderer/components/RNPencilKitSpec/RCTComponentViewHelpers.h>

#import "RCTFabricComponentsPlugins.h"

using namespace facebook::react;

static inline const std::shared_ptr<const RNPencilKitEventEmitter>
getEmitter(const SharedViewEventEmitter emitter) {
  return std::static_pointer_cast<const RNPencilKitEventEmitter>(emitter);
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
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNPencilKitProps>();
    _props = defaultProps;
    _view = [[PKCanvasView alloc] initWithFrame:frame];
    _view.backgroundColor = [UIColor clearColor];

    _view.delegate = self;
    _toolPicker = [[PKToolPicker alloc] init];
    [_toolPicker addObserver:_view];
    [_toolPicker addObserver:self];
    [_toolPicker setVisible:YES forFirstResponder:_view];
    self.contentView = _view;

    // ── Register for Pencil double-tap (2nd-gen Pencil or Apple Pencil Pro) ──
    if (@available(iOS 12.1, *)) {
      UIPencilInteraction* pencilInteraction = [[UIPencilInteraction alloc] init];
      pencilInteraction.delegate = self;
      [_view addInteraction:pencilInteraction];
    }
  }

  return self;
}

- (void)dealloc {
  [_toolPicker removeObserver:_view];
  [_toolPicker removeObserver:self];
}

- (void)scrollViewWillBeginZooming:(UIScrollView*)scrollView withView:(UIView*)view {
  // Clear content inset when zooming begins to avoid interference
  _lastEdgeInsets = (UIEdgeInsets){.top = _view.contentInset.top / _view.zoomScale,
                                   .left = _view.contentInset.left / _view.zoomScale,
                                   .bottom = _view.contentInset.bottom / _view.zoomScale,
                                   .right = _view.contentInset.right / _view.zoomScale};
  _view.contentInset = UIEdgeInsetsZero;
}

- (void)scrollViewDidEndZooming:(UIScrollView*)scrollView
                       withView:(UIView*)view
                        atScale:(CGFloat)scale {
  // Restore content inset when zooming ends
  // [self updateContentInset];
  _view.contentInset = (UIEdgeInsets){.top = _lastEdgeInsets.top * _view.zoomScale,
                                      .left = _lastEdgeInsets.left * _view.zoomScale,
                                      .bottom = _lastEdgeInsets.bottom * _view.zoomScale,
                                      .right = _lastEdgeInsets.right * _view.zoomScale};
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
    [_view setBackgroundColor:intToColor(next.backgroundColor)];
  }

  if (prev.allowInfiniteScroll ^ next.allowInfiniteScroll) {
    _allowInfiniteScroll = next.allowInfiniteScroll;
    _view.contentSize = next.allowInfiniteScroll ? CGSizeMake(10000, 10000) : CGSizeZero;
    if (next.allowInfiniteScroll) {
      [self updateContentInset];
    }
  }

  if (prev.minimumZoomScale != next.minimumZoomScale)
    _view.minimumZoomScale = next.minimumZoomScale;

  if (prev.maximumZoomScale != next.maximumZoomScale)
    _view.maximumZoomScale = next.maximumZoomScale;

  [super updateProps:props oldProps:oldProps];
}

- (void)layoutSubviews {
  [super layoutSubviews];
}

- (void)updateContentInset {
  // don't bother if the allowInfiniteScroll prop isn't set
  if (!_allowInfiniteScroll) {
    return;
  }

  const CGFloat z = MAX(_view.zoomScale, 0.0001);

  // Visible size in content coordinates
  const CGSize viewportInContent = (CGSize){_view.bounds.size.width, _view.bounds.size.height};

  // ✅ Correct: visible origin must include contentInset
  const CGPoint visibleOriginInContent = (CGPoint){_view.bounds.origin.x, _view.bounds.origin.y};

  const CGRect visible = (CGRect){visibleOriginInContent, viewportInContent};

  if (CGSizeEqualToSize(_view.drawing.bounds.size, CGSizeZero)) {
    // Center an empty canvas using viewportInContent, not raw bounds
    const CGFloat leftInset = (_view.contentSize.width - viewportInContent.width) / 2.0;
    const CGFloat topInset = (_view.contentSize.height - viewportInContent.height) / 2.0;

    _view.contentInset = (UIEdgeInsets){
        .top = -topInset,
        .left = -leftInset,
        .bottom = -topInset,
        .right = -leftInset,
    };
    return;
  }

  const CGRect drawing =
      (CGRect){.origin = (CGPoint){_view.drawing.bounds.origin.x * _view.zoomScale,
                                   _view.drawing.bounds.origin.y * _view.zoomScale},
               .size = (CGSize){_view.drawing.bounds.size.width * _view.zoomScale,
                                _view.drawing.bounds.size.height * _view.zoomScale}};

  // One-viewport padding (in content coordinates)
  const CGFloat padX = viewportInContent.width;
  const CGFloat padY = viewportInContent.height;

  // Expand the ink bounds symmetrically
  const CGRect expanded = CGRectInset(drawing, -padX, -padY);

  // Include what's currently on screen (correctly measured)
  CGRect finalContentBounds = CGRectUnion(expanded, visible);

  // (Optional) Keep bounds inside contentSize to avoid pathological insets
  finalContentBounds.origin.x = MAX(0, finalContentBounds.origin.x);
  finalContentBounds.origin.y = MAX(0, finalContentBounds.origin.y);
  finalContentBounds.size.width =
      MIN(finalContentBounds.size.width, _view.contentSize.width - finalContentBounds.origin.x);
  finalContentBounds.size.height =
      MIN(finalContentBounds.size.height, _view.contentSize.height - finalContentBounds.origin.y);

  _view.contentInset = (UIEdgeInsets){
      .top = -finalContentBounds.origin.y,
      .left = -finalContentBounds.origin.x,
      .bottom = -(_view.contentSize.height - CGRectGetMaxY(finalContentBounds)),
      .right = -(_view.contentSize.width - CGRectGetMaxX(finalContentBounds)),
  };
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

// - (NSString*)getBase64PngData:(double)scale {
//   return [self getBase64PngData:scale x:0 y:0 width:0 height:0];
// }

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

    rect = CGRectMake(_view.bounds.origin.x + (x / _view.zoomScale),
                      _view.bounds.origin.y + (y / _view.zoomScale), width / _view.zoomScale,
                      height / _view.zoomScale);
  } else {
    // Use the default bounds
    rect = _view.bounds;
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
  PKCanvasView* newView = [[PKCanvasView alloc] initWithFrame:v.frame];
  newView.alwaysBounceVertical = v.alwaysBounceVertical;
  newView.alwaysBounceHorizontal = v.alwaysBounceHorizontal;
  [newView setRulerActive:v.isRulerActive];
  [newView setBackgroundColor:v.backgroundColor];
  [newView setDrawingPolicy:v.drawingPolicy];
  [newView setOpaque:v.isOpaque];
  newView.contentSize = v.contentSize;
  newView.contentInset = v.contentInset;
  newView.minimumZoomScale = v.minimumZoomScale;
  newView.maximumZoomScale = v.maximumZoomScale;
  newView.bounds = v.bounds;
  newView.delegate = self;

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
