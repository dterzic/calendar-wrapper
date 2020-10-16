#import "NSDictionary+GCWCalendarEvent.h"

#import "GCWCalendarEvent.h"

@implementation NSDictionary (GCWCalendarEvent)

- (NSDictionary *)calendarEvents {
    return self;
}

+ (NSDictionary *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableDictionary *events = [NSMutableDictionary dictionary];
    for (NSData *data in archive) {
        GCWCalendarEvent *event = (GCWCalendarEvent *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        [events setValue:event forKey:event.identifier];
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self.allValues) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event];
        [archiveArray addObject:data];
    }
    return archiveArray;
}

@end
