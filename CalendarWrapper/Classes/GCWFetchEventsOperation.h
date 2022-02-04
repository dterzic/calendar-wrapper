#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWFetchEventsOperation : NSOperation

@property (nonatomic) NSDictionary *_Nullable fetchPageTokens;
@property (nonatomic) NSError *_Nullable error;

- (instancetype _Nullable)initWithCalendar:(GCWCalendar *_Nonnull)calendar
                                 startDate:(NSDate *_Nonnull)startDate
                                 ascending:(BOOL)ascending
                                    filter:(NSString *_Nullable)filter;

@end
