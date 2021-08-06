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

@end
