#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@interface GCWCalendarEntry : GTLRCalendar_CalendarListEntry

@property (nonatomic) BOOL hideEvents;

- (instancetype)initWithCalendarListEntry:(GTLRCalendar_CalendarListEntry *)entry;

@end
