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

+ (NSDateFormatter *)rfc3339X5Formatter {
    static NSDateFormatter *_rfc3339Formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _rfc3339Formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [_rfc3339Formatter setLocale:enUSPOSIXLocale];
        [_rfc3339Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSX5"];
        [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    });

    return _rfc3339Formatter;
}

+ (NSDateFormatter *)rfc3339Formatter {
    static NSDateFormatter *_rfc3339Formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _rfc3339Formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [_rfc3339Formatter setLocale:enUSPOSIXLocale];
        [_rfc3339Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [_rfc3339Formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    });

    return _rfc3339Formatter;
}

@end
