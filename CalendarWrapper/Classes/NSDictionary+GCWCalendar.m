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
        GCWCalendarEntry *entry = (GCWCalendarEntry *)[NSKeyedUnarchiver unarchiveObjectWithData:data];
        [entries setValue:entry forKey:key];
    }];
    return [entries copy];
}

- (NSDictionary *)archiveCalendarEntries {
    NSMutableDictionary *archiveDictionary = [NSMutableDictionary dictionaryWithCapacity:self.count];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        GCWCalendarEntry *entry = (GCWCalendarEntry *)obj;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:entry];
        [archiveDictionary setValue:data forKey:key];
    }];
    return archiveDictionary;
}

@end
