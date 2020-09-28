#import <Foundation/Foundation.h>

@class GCWCalendarEvent;

@interface NSArray (GCWCalendarEvent)

@property (nonatomic, readonly) NSArray <GCWCalendarEvent *> *calendarEvents;

+ (NSArray *)unarchiveCalendarEventsFrom:(NSArray *)archive;
- (NSArray *)archiveCalendarEvents;

@end
