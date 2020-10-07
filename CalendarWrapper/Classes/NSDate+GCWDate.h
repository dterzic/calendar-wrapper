#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GCWCalendarDayType) {
    GCWCalendarDayTypeToday,
    GCWCalendarDayTypeYesterday,
    GCWCalendarDayTypeTomorrow,
    GCWCalendarDayTypeNormal
};

@interface NSDate (GCWDate)

@property (nonatomic, readonly) NSDate *dayOnly;
@property (nonatomic, readonly) GCWCalendarDayType dayType;
@property (nonatomic, readonly) BOOL isInCurrentYear;

+ (NSDate *)dateFromNumberOfMonthSinceNow:(NSInteger)month;
+ (NSDate *)dateFromNumberOfDaysSinceNow:(NSInteger)days;

- (BOOL)inSameDayAsDate:(NSDate *)date;
- (NSDate *)dateFromNumberOfMonth:(NSInteger)month;
- (NSDate *)dateFromNumberOfDays:(NSInteger)days;

@end
