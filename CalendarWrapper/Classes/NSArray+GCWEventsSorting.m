#import "NSArray+GCWEventsSorting.h"

#import "GCWCalendarEvent.h"
#import "NSDate+GCWDate.h"

@implementation NSArray (GCWEventsSorting)

- (NSArray<GCWCalendarEvent *> *)eventsFlatMap {
    NSMutableArray *events = [NSMutableArray array];
    for (id item in self) {
        if ([item isKindOfClass:NSDictionary.class]) {
            NSDictionary *items = (NSDictionary *)item;
            [events addObjectsFromArray:items.allValues];
        } else if ([item isKindOfClass:GCWCalendarEvent.class]) {
            GCWCalendarEvent *event = (GCWCalendarEvent *)item;
            [events addObject:event];
        } else {
            assert("Unexpected calendar event type");
        }
    }
    return events.copy;
}

- (NSArray *)sortedEvents {
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeIntervalSinceEpochTime" ascending:YES];
    return [self sortedArrayUsingDescriptors:@[sortDescriptor]];
}

- (NSArray *)eventsWithDeclinedEvents:(BOOL)showDeclined {
    NSMutableArray <GCWCalendarEvent *> *events = [NSMutableArray array];
    for (GCWCalendarEvent *event in self.sortedEvents) {
        if (!showDeclined) {
            if (event.responseStatus == GCWCalendarEventResponseStatusDeclined) {
                continue;
            }
        }
        [events addObject:event];
    }
    
    return events;
}

- (NSArray <NSArray <GCWCalendarEvent *> *> *)eventsGroupedByDay{
    NSMutableArray <NSMutableArray *> *events = [NSMutableArray array];
    NSDate *stageStartDateDayOnly;
    for (GCWCalendarEvent *event in [self sortedEvents]) {
        if (![event.startDateDayOnly inSameDayAsDate:stageStartDateDayOnly]) {
            NSMutableArray *eventsWithNewDay = [NSMutableArray array];
            stageStartDateDayOnly = event.startDateDayOnly;
            [events addObject:eventsWithNewDay];
        }
        [events.lastObject addObject:event];
    }
    
    return events;
}

@end
