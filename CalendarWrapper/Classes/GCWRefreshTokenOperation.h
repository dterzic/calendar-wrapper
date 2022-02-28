#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWRefreshTokenOperation : NSOperation

@property (nonatomic) NSError *_Nullable error;

- (instancetype _Nullable)initWithCalendar:(GCWCalendar *_Nonnull)calendar;

@end
