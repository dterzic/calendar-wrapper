#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWSyncEventsOperation : NSOperation

@property (nonatomic) NSDictionary *_Nullable syncedEvents;
@property (nonatomic) NSArray *_Nullable removedEvents;
@property (nonatomic) NSArray *_Nullable expiredTokens;
@property (nonatomic) NSError *_Nullable error;

- (instancetype _Nullable)initWithCalendar:(GCWCalendar *_Nonnull)calendar
                                 startDate:(NSDate *_Nonnull)startDate
                                   endDate:(NSDate *_Nonnull)endDate;

@end
