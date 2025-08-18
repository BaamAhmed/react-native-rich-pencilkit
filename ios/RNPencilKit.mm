#import "RNPencilKit.h"

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
                           UIPencilInteractionDelegate>

@end

@implementation RNPencilKit {
  PKCanvasView* _Nonnull _view;
  PKToolPicker* _Nullable _toolPicker;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const RNPencilKitProps>();
    _props = defaultProps;
    _view = [[PKCanvasView alloc] initWithFrame:frame];
    // _view.minimumZoomScale = 0.2;
    // _view.maximumZoomScale = 4.0;
    _view.backgroundColor = [UIColor clearColor];

    // Initialize with viewport-based content size and insets
    CGSize viewportSize = frame.size;
    CGSize initialContentSize = CGSizeMake(viewportSize.width * 2, viewportSize.height * 2);
    _view.contentSize = initialContentSize;

    // Center the viewport in the initial content size
    CGFloat leftInset = (initialContentSize.width - viewportSize.width) / 2;
    CGFloat topInset = (initialContentSize.height - viewportSize.height) / 2;
    _view.contentInset = UIEdgeInsetsMake(-topInset, -leftInset, -topInset, -leftInset);

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

- (void)scrollViewDidZoom:(UIScrollView*)scrollView {
  // No longer needed since we removed border layer
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

  // if (prev.minimumZoomScale != next.minimumZoomScale) {
  //   _view.minimumZoomScale = next.minimumZoomScale;
  // }

  // if (prev.maximumZoomScale != next.maximumZoomScale) {
  //   _view.maximumZoomScale = next.maximumZoomScale;
  // }

  // All content size, insets, and styling are now handled by infinite scrolling implementation

  [super updateProps:props oldProps:oldProps];
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

- (NSString*)getBase64PngData:(double)scale {
  NSData* data = _view.drawing.dataRepresentation;
  if (!data) {
    return nil;
  }
  UIImage* image = [_view.drawing imageFromRect:_view.bounds
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
  newView.delegate = self;
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
    const int THRESH = 200;

    /**
     Implementation of infinite scrolling canvas:
     1. Calculate viewport-based margins
     2. Adjust content insets based on drawing bounds
     3. Handle both empty and non-empty drawing cases
     */

    PKDrawing* currentDrawing = canvasView.drawing;
    CGRect viewportBounds = _view.bounds;
    CGRect drawingBounds = currentDrawing.bounds;
    CGFloat zoomScale = _view.zoomScale;

    // Create viewport-sized margins
    UIEdgeInsets viewportMargins =
        UIEdgeInsetsMake(-viewportBounds.size.height, -viewportBounds.size.width,
                         -viewportBounds.size.height, -viewportBounds.size.width);

    if (CGSizeEqualToSize(drawingBounds.size, CGSizeZero)) {
      // No drawing case - center the viewport
      CGFloat leftInset = (_view.contentSize.width - viewportBounds.size.width) / 2;
      CGFloat topInset = (_view.contentSize.height - viewportBounds.size.height) / 2;

      _view.contentInset = UIEdgeInsetsMake(-topInset, -leftInset, -topInset, -leftInset);
    } else {
      // Existing drawing case
      CGRect realContentBounds = CGRectInset(drawingBounds, viewportMargins.left / zoomScale,
                                             viewportMargins.top / zoomScale);

      // Union with viewport to include visible area
      CGRect finalContentBounds =
          CGRectUnion(realContentBounds, CGRectMake(0, 0, viewportBounds.size.width / zoomScale,
                                                    viewportBounds.size.height / zoomScale));

      // Track if we need to shift the drawing
      CGFloat drawingShiftX = 0;
      CGFloat drawingShiftY = 0;

      // Check if we need to expand left or top
      if (finalContentBounds.origin.x < 0) {
        drawingShiftX = -finalContentBounds.origin.x;
        finalContentBounds.size.width += drawingShiftX;
        finalContentBounds.origin.x = 0;
      }
      if (finalContentBounds.origin.y < 0) {
        drawingShiftY = -finalContentBounds.origin.y;
        finalContentBounds.size.height += drawingShiftY;
        finalContentBounds.origin.y = 0;
      }

      // Calculate new content size to accommodate the drawing
      CGSize newContentSize =
          CGSizeMake(MAX(_view.contentSize.width,
                         finalContentBounds.size.width * zoomScale + viewportBounds.size.width),
                     MAX(_view.contentSize.height,
                         finalContentBounds.size.height * zoomScale + viewportBounds.size.height));

      // If we need to shift the drawing, do it before changing content size
      if (drawingShiftX > 0 || drawingShiftY > 0) {
        // Store current content offset before shifting
        CGPoint currentOffset = _view.contentOffset;

        // Shift the drawing
        PKDrawing* shiftedDrawing = [currentDrawing
            drawingByApplyingTransform:CGAffineTransformMakeTranslation(drawingShiftX,
                                                                        drawingShiftY)];
        [_view setDrawing:shiftedDrawing];

        // Adjust content offset by the same amount we shifted the drawing
        CGPoint newOffset = CGPointMake(currentOffset.x + (drawingShiftX * zoomScale),
                                        currentOffset.y + (drawingShiftY * zoomScale));
        _view.contentOffset = newOffset;
      }

      // Set new content size if it changed
      if (!CGSizeEqualToSize(_view.contentSize, newContentSize)) {
        _view.contentSize = newContentSize;
      }

      // Update content insets to allow scrolling only within the useful content area
      _view.contentInset =
          UIEdgeInsetsMake(0, // Top inset starts at 0 since we shifted the drawing
                           0, // Left inset starts at 0 since we shifted the drawing
                           -(newContentSize.height - finalContentBounds.size.height * zoomScale),
                           -(newContentSize.width - finalContentBounds.size.width * zoomScale));
    }

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
