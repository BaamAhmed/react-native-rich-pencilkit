// This guard prevent this file to be compiled in the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
#import "RNPencilKitUtilFunction.h"
#import <PencilKit/PencilKit.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTViewComponentView.h>
#import <UIKit/UIKit.h>

#ifndef RNPencilKitNativeComponent_h
#define RNPencilKitNativeComponent_h

NS_ASSUME_NONNULL_BEGIN

@interface RNPencilKit : RCTViewComponentView
- (NSString*)getBase64Data;
- (NSDictionary*)getDrawingBounds;
- (NSString*)getBase64PngData:(double)scale;
- (NSString*)getBase64PngData:(double)scale
                            x:(double)x
                            y:(double)y
                        width:(double)width
                       height:(double)height;
- (NSString*)getBase64JpegData:(double)scale compression:(double)compression;
- (NSString*)saveDrawing:(nonnull NSString*)path;
- (BOOL)loadDrawing:(nonnull NSString*)path;
- (BOOL)loadBase64Data:(nonnull NSString*)base64;
@end

NS_ASSUME_NONNULL_END

#endif /* RNPencilKitNativeComponent_h */
#endif /* RCT_NEW_ARCH_ENABLED */
