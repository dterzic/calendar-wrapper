#import "NSDate+GCWDate.h"

#import <Foundation/NSCalendar.h>

@implementation NSDate (GCWDate)

- (NSDate *)dateWithDaylightSavingOffset {
    BOOL isDaylightSaving = [NSTimeZone.localTimeZone isDaylightSavingTimeForDate:self];

    if (isDaylightSaving) {
        NSInteger daylightSavingOffset = [NSTimeZone.localTimeZone daylightSavingTimeOffsetForDate:self];
        return [self dateByAddingTimeInterval:daylightSavingOffset];
    } else {
        return self;
    }
}

+ (NSDate *)addTimeFrom:(NSDate *)time to:(NSDate *)date {
    NSDateComponents *dateComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear  fromDate:date];
    NSDateComponents *timeComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:time];

    [dateComponents setHour:[timeComponents hour]];
    [dateComponents setMinute:[timeComponents minute]];

    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    return [calendar dateFromComponents:dateComponents];
}

- (NSDate *)dateFromNumberOfMonths:(NSInteger)months {
    return [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitMonth
                                                  value:months
                                                 toDate:self
                                                options:0];
}

- (NSDate *)dateFromNumberOfHours:(NSInteger)hours {
    return [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitHour
                                                  value:hours
                                                 toDate:self
                                                options:0];
}

- (NSDate *)dateFromNumberOfSeconds:(NSInteger)seconds {
    return [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitSecond
                                                  value:seconds
                                                 toDate:self
                                                options:0];
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

-(BOOL) isLaterThanOrEqualTo:(NSDate*)date {
    return !([self compare:date] == NSOrderedAscending);
}

-(BOOL) isEarlierThanOrEqualTo:(NSDate*)date {
    return !([self compare:date] == NSOrderedDescending);
}

-(BOOL) isLaterThan:(NSDate*)date {
    return ([self compare:date] == NSOrderedDescending);

}

-(BOOL) isEarlierThan:(NSDate*)date {
    return ([self compare:date] == NSOrderedAscending);
}

- (NSInteger)numberOfDaysUntil:(NSDate *)date {
    NSDateComponents *components = [NSCalendar.currentCalendar components:NSCalendarUnitDay
                                                                 fromDate:self
                                                                   toDate:date
                                                                  options:0];
    return components.day;
}

@end
