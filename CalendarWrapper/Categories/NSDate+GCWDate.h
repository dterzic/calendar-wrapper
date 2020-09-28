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
- (BOOL)inSameDayAsDate:(NSDate *)date;

@end
