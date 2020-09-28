#import "NSDate+GCWDate.h"

#import <Foundation/NSCalendar.h>

@implementation NSDate (GCWDate)

+ (NSDate *)dateFromNumberOfMonthSinceNow:(NSInteger)month {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [NSDateComponents new];
    dateComponents.month = month;
    return [calendar dateByAddingComponents:dateComponents toDate:[NSDate date] options:NSCalendarMatchStrictly];
}

- (NSDate *)dayOnly {
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                                                   fromDate:self];
    return [[NSCalendar currentCalendar] dateFromComponents:components];
}

- (BOOL)isInCurrentYear {
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                                       fromDate:self];
    NSDateComponents *nowComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear
                                                                      fromDate:[NSDate date]];
    return dateComponents.year == nowComponents.year;
}

- (GCWCalendarDayType)dayType {
    if ([[NSCalendar currentCalendar] isDateInToday:self]) {
        return GCWCalendarDayTypeToday;
    } else if ([[NSCalendar currentCalendar] isDateInTomorrow:self]) {
        return GCWCalendarDayTypeTomorrow;
    } else if ([[NSCalendar currentCalendar] isDateInYesterday:self]) {
        return GCWCalendarDayTypeYesterday;
    } else {
        return GCWCalendarDayTypeNormal;
    }
}

- (BOOL)inSameDayAsDate:(NSDate *)date {
    return date ? [[NSCalendar currentCalendar] isDate:self inSameDayAsDate:date] : NO;
}

@end
