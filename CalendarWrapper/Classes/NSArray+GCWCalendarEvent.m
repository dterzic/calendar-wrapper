#import "NSArray+GCWCalendarEvent.h"
#import "GCWCalendarEvent.h"

static NSString *const kCalendarEventKey = @"calendarWrapperCalendarEventKey";


@implementation NSArray (GCWCalendarEvent)

- (NSArray *)calendarEvents {
    return self;
}

+ (NSArray *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableArray *events = [NSMutableArray array];
    for (NSData *data in archive) {
        NSError *error = nil;
        NSKeyedUnarchiver *secureDecoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];

        if (error) {
            NSLog(@"NSArray: Unarchive event failed with error: %@", error);
        } else {
            [secureDecoder setRequiresSecureCoding:YES];

            NSSet *classes = [NSSet setWithObjects:GCWCalendarEvent.class, UIColor.class, NSString.class, nil];
            GCWCalendarEvent *event = [secureDecoder decodeObjectOfClasses:classes forKey:kCalendarEventKey];

            [events addObject:event];
        }
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self) {
        NSKeyedArchiver *secureEncoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

        [secureEncoder encodeObject:event forKey:kCalendarEventKey];
        [secureEncoder finishEncoding];

        NSData *data = [secureEncoder encodedData];

        [archiveArray addObject:data];
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
