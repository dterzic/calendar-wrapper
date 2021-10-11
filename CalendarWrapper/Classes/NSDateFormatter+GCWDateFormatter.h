#import <Foundation/Foundation.h>

@interface NSDateFormatter (GCWDateFormatter)

+ (NSDateFormatter *)dayHourFormatter;
+ (NSDateFormatter *)weekDayWithDateFormatter;
+ (NSDateFormatter *)weekDayWithDateYearFormatter;
+ (NSDateFormatter *)rfc3339X5Formatter;
+ (NSDateFormatter *)rfc3339Formatter;

@end
