#import "NSDictionary+GCWCalendar.h"

#import "GCWCalendarEntry.h"

@implementation NSDictionary (GCWCalendarEntry)

- (NSDictionary *)calendars {
    return self;
}

+ (NSDictionary *)unarchiveCalendarEntriesFrom:(NSDictionary *)archive {
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];

    [archive enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSData *data = (NSData *)obj;
        NSError *error = nil;
        GCWCalendarEntry *entry = [NSKeyedUnarchiver unarchivedObjectOfClass:GCWCalendarEntry.class fromData:data error:&error];
        if (error) {
            NSLog(@"Archive entry failed with error: %@", error);
        } else {
            [entries setValue:entry forKey:key];
        }
    }];
    return [entries copy];
}

- (NSDictionary *)archiveCalendarEntries {
    NSMutableDictionary *archiveDictionary = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        GCWCalendarEntry *entry = (GCWCalendarEntry *)obj;
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry requiringSecureCoding:NO error:&error];
        if (error) {
            NSLog(@"Archive entry failed with error: %@", error);
        } else {
            [archiveDictionary setValue:data forKey:key];
        }
    }];
    return archiveDictionary;
}

@end
