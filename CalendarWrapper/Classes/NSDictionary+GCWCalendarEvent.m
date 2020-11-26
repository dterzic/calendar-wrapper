#import "NSDictionary+GCWCalendarEvent.h"

#import "GCWCalendarEvent.h"

@implementation NSDictionary (GCWCalendarEvent)

- (NSDictionary *)calendarEvents {
    return self;
}

+ (NSDictionary *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableDictionary *events = [NSMutableDictionary dictionary];
    for (NSData *data in archive) {
        NSError *error = nil;
        GCWCalendarEvent *event = [NSKeyedUnarchiver unarchivedObjectOfClass:GCWCalendarEvent.class fromData:data error:&error];
        if (error) {
            NSLog(@"NSDictionary: Unarchive event failed with error: %@", error);
        } else {
            [events setValue:event forKey:event.identifier];
        }
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self.allValues) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:event requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"NSDictionary: Archive event failed with error: %@", error);
        } else {
            [archiveArray addObject:data];
        }
    }
    return archiveArray;
}

@end
