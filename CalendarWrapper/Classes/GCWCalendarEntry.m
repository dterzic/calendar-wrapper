#import "GCWCalendarEntry.h"

@implementation GCWCalendarEntry

- (instancetype)initWithCalendarListEntry:(GTLRCalendar_CalendarListEntry *)entry {
    return [[self class] objectWithJSON:entry.JSON];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self != nil) {
        NSString *jsonString = [coder decodeObjectForKey:@"GCWCalendarEntryJSON"];
        NSError *jsonError;
        NSData *objectData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                              options:NSJSONReadingMutableContainers
                                                error:&jsonError];
        if (!jsonError) {
            GCWCalendarEntry *calendar = [[self class] objectWithJSON:json];
            calendar.hideEvents = [coder decodeBoolForKey:@"GCWCalendarEntryHideEvents"];
            return calendar;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self JSONString] forKey:@"GCWCalendarEntryJSON"];
    [coder encodeBool:self.hideEvents forKey:@"GCWCalendarEntryHideEvents"];
}

@end
