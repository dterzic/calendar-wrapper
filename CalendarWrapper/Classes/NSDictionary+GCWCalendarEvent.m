#import "NSDictionary+GCWCalendarEvent.h"
#import "NSArray+GCWCalendarEvent.h"
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

            NSSet *classes = [NSSet setWithObjects:GCWCalendarEvent.class, UIColor.class, NSString.class, nil];
            GCWCalendarEvent *event = [secureDecoder decodeObjectOfClasses:classes forKey:kCalendarEventKey];

            id item = [events valueForKey:event.identifier];

            if ([item isKindOfClass:NSDictionary.class]) {
                NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)item];
                items[event.calendarId] = event;
                [events setValue:items forKey:event.identifier];
            } else {
                GCWCalendarEvent *cachedEvent = (GCWCalendarEvent *)item;

                if (cachedEvent == nil || [cachedEvent.calendarId isEqualToString:event.calendarId]) {
                    [events setValue:event forKey:event.identifier];
                } else {
                    NSMutableDictionary *items = [NSMutableDictionary dictionary];
                    items[event.calendarId] = event;
                    items[cachedEvent.calendarId] = cachedEvent;
                    [events setValue:items forKey:event.identifier];
                }
            }
        }
    }
    return [events copy];
}

- (NSArray *)archiveCalendarEvents {
    NSMutableArray *archiveArray = [NSMutableArray arrayWithCapacity:self.count];
    for (id item in self.allValues) {
        if ([item isKindOfClass:NSDictionary.class]) {
            NSDictionary *itemsDictionary = (NSDictionary *)item;

            for (GCWCalendarEvent *event in itemsDictionary.allValues) {
                NSKeyedArchiver *secureEncoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

                [secureEncoder encodeObject:event forKey:kCalendarEventKey];
                [secureEncoder finishEncoding];

                NSData *data = [secureEncoder encodedData];

                [archiveArray addObject:data];
            }
        } else if ([item isKindOfClass:GCWCalendarEvent.class]) {
            NSKeyedArchiver *secureEncoder = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];

            GCWCalendarEvent *event = (GCWCalendarEvent *)item;

            [secureEncoder encodeObject:event forKey:kCalendarEventKey];
            [secureEncoder finishEncoding];

            NSData *data = [secureEncoder encodedData];

            [archiveArray addObject:data];
        } else {
            assert("Archive event invalid type");
        }
    }
    return archiveArray;
}

@end
