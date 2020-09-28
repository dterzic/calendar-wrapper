#import <Foundation/Foundation.h>

@interface NSDateFormatter (GCWDateFormatter)

+ (NSDateFormatter *)dayHourFormatter;
+ (NSDateFormatter *)weekDayWithDateFormatter;
+ (NSDateFormatter *)weekDayWithDateYearFormatter;

@end
