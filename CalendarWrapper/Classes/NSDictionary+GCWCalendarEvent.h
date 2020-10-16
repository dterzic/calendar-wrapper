#import <Foundation/Foundation.h>

@class GCWCalendarEvent;

@interface NSDictionary (GCWCalendarEvent)

@property (nonatomic, readonly) NSDictionary <NSString *, GCWCalendarEvent *> *calendarEvents;

+ (NSDictionary *)unarchiveCalendarEventsFrom:(NSArray *)archive;
- (NSArray *)archiveCalendarEvents;

@end
