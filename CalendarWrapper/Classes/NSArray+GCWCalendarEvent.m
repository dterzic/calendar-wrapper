#import "NSArray+GCWCalendarEvent.h"

#import "GCWCalendarEvent.h"

@implementation NSArray (GCWCalendarEvent)

- (NSArray *)calendarEvents {
    return self;
}

+ (NSArray *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableArray *events = [NSMutableArray array];
    for (NSData *data in archive) {
        NSError *error = nil;
        GCWCalendarEvent *event = [NSKeyedUnarchiver unarchivedObjectOfClass:GCWCalendarEvent.class fromData:data error:&error];
        if (error) {
            NSLog(@"NSArray: Unarchive event failed with error: %@", error);
        } else {
            [events addObject:event];
        }
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"NSArray: Archive event failed with error: %@", error);
        } else {
            [archiveArray addObject:data];
        }
    }
    return archiveArray;
}

- (GCWCalendarEvent *)eventWithId:(NSString *)eventId forCalendar:(NSString *)calendarId {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@ && calendarId == %@", eventId, calendarId];
    NSArray *filteredArray = [self filteredArrayUsingPredicate:predicate];

    NSAssert((filteredArray.count <= 1), @"Calendar event not unique!");

    if (filteredArray.count) {
        return filteredArray[0];
    }
    return nil;
}

@end
