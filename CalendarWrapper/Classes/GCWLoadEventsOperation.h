#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWLoadEventsOperation : NSOperation

@property (nonatomic) NSDictionary *_Nullable loadedEvents;
@property (nonatomic) NSArray *_Nullable removedEvents;
@property (nonatomic) NSUInteger filteredEventsCount;
@property (nonatomic) NSError *_Nullable error;

- (instancetype _Nullable)initWithCalendar:(GCWCalendar *_Nonnull)calendar
                                 startDate:(NSDate *_Nonnull)startDate
                                   endDate:(NSDate *_Nonnull)endDate
                                    filter:(NSString *_Nullable)filter;

@end
