#import <Foundation/Foundation.h>

@class GCWCalendarEvent;

@interface NSArray (GCWEventsSorting)

@property (nonatomic, readonly) NSArray <GCWCalendarEvent *> *eventsFlatMap;
@property (nonatomic, readonly) NSArray <NSArray <NSArray <GCWCalendarEvent *> *> *> *eventsGroupedByDay;

- (NSArray *)eventsWithDeclinedEvents:(BOOL)showDeclined;

@end
