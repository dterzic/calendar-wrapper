#import "NSArray+GCWCalendarEntry.h"
#import "GCWCalendarEntry.h"

@implementation NSArray (GCWCalendarEntry)

- (NSArray *)calendars {
    return self;
}

- (GCWCalendarEntry *)calendarWithId:(NSString *)calendarId {
    NSUInteger index = [self indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GCWCalendarEntry *calendar = obj;
        return [calendar.identifier isEqualToString:calendarId];
    }];
    if (index >= 0 && index < self.count) {
        GCWCalendarEntry *calendar = self[index];
        return calendar;
    }
    return nil;
}

- (GCWCalendarEntry *)calendarWithTitle:(NSString *)title {
    NSUInteger index = [self indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GCWCalendarEntry *calendar = obj;
        return [calendar.summary isEqualToString:title];
    }];
    if (index >= 0 && index < self.count) {
        GCWCalendarEntry *calendar = self[index];
        return calendar;
    }
    return nil;
}

@end
