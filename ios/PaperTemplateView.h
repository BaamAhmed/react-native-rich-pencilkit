#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PaperTemplateType) {
  PaperTemplateTypeBlank = 0,
  PaperTemplateTypeLined,
  PaperTemplateTypeDotted,
  PaperTemplateTypeGrid
};

@interface PaperTemplateView : UIView
@property(nonatomic, assign) PaperTemplateType templateType;
@property(nonatomic, strong) UIColor* paperBackgroundColor;
@property(nonatomic, assign) CGFloat zoomScale;
- (instancetype)initWithFrame:(CGRect)frame
                 templateType:(PaperTemplateType)templateType
              backgroundColor:(UIColor* _Nullable)backgroundColor;
@end

NS_ASSUME_NONNULL_END
