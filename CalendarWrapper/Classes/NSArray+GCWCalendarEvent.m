#import "NSArray+GCWCalendarEvent.h"

#import "GCWCalendarEvent.h"

@implementation NSArray (GCWCalendarEvent)

- (NSArray *)calendarEvents {
    return self;
}

+ (NSArray *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableArray *events = [NSMutableArray array];
    for (NSData *data in archive) {
        GCWCalendarEvent *event = (GCWCalendarEvent *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        [events addObject:event];
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event];
        [archiveArray addObject:data];
    }
    return archiveArray;
}

@end
