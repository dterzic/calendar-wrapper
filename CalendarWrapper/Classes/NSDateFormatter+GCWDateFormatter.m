#import "NSDateFormatter+GCWDateFormatter.h"

@implementation NSDateFormatter (GCWDateFormatter)

+ (NSDateFormatter *)dayHourFormatter {
    static NSDateFormatter *_dayHourFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _dayHourFormatter = [[NSDateFormatter alloc] init];
        _dayHourFormatter.dateFormat = @"h:mm a";
    });

    return _dayHourFormatter;
}

+ (NSDateFormatter *)weekDayWithDateFormatter {
    static NSDateFormatter *_weekDayWithDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _weekDayWithDateFormatter = [[NSDateFormatter alloc] init];
        _weekDayWithDateFormatter.dateFormat = @"EEEE, MMMM d";
    });

    return _weekDayWithDateFormatter;
}

+ (NSDateFormatter *)weekDayWithDateYearFormatter {
    static NSDateFormatter *_weekDayWithDateYearFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _weekDayWithDateYearFormatter = [[NSDateFormatter alloc] init];
        _weekDayWithDateYearFormatter.dateFormat = @"EEEE, MMMM d, yyyy";
    });

    return _weekDayWithDateYearFormatter;
}

@end
