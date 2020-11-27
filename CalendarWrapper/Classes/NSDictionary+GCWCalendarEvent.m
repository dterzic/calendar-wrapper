#import "NSDictionary+GCWCalendarEvent.h"
#import "GCWCalendarEvent.h"

static NSString *const kCalendarEventKey = @"calendarWrapperCalendarEventKey";


@implementation NSDictionary (GCWCalendarEvent)

- (NSDictionary *)calendarEvents {
    return self;
}

+ (NSDictionary *)unarchiveCalendarEventsFrom:(NSArray *)archive {
    NSMutableDictionary *events = [NSMutableDictionary dictionary];
    for (NSData *data in archive) {
        NSError *error = nil;
        NSKeyedUnarchiver *secureDecoder = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];

        if (error) {
            NSLog(@"Unarchive event failed with error: %@", error);
        } else {
            [secureDecoder setRequiresSecureCoding:YES];

            NSSet *classes = [NSSet setWithObjects:GCWCalendarEvent.class, UIColor.class, nil];
            GCWCalendarEvent *event = [secureDecoder decodeObjectOfClasses:classes forKey:kCalendarEventKey];

            [events setValue:event forKey:event.identifier];
        }
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (GCWCalendarEvent *event in self.allValues) {
        NSKeyedArchiver *secureEncoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

        [secureEncoder encodeObject:event forKey:kCalendarEventKey];
        [secureEncoder finishEncoding];

        NSData *data = [secureEncoder encodedData];

        [archiveArray addObject:data];
    }
    return archiveArray;
}

@end
