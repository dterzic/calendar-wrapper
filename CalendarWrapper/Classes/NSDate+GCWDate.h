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

+ (NSDate *)addTimeFrom:(NSDate *)time to:(NSDate *)date;

- (BOOL)inSameDayAsDate:(NSDate *)date;
- (BOOL)isLaterThanOrEqualTo:(NSDate*)date;
- (BOOL)isEarlierThanOrEqualTo:(NSDate*)date;
- (BOOL)isLaterThan:(NSDate*)date;
- (BOOL)isEarlierThan:(NSDate*)date;

- (NSDate *)dateFromNumberOfMonths:(NSInteger)months;
- (NSDate *)dateFromNumberOfHours:(NSInteger)hours;
- (NSDate *)dateByAddingSeconds:(NSInteger)seconds;
- (NSDate *)dateWithDaylightSavingOffset;
- (NSInteger)numberOfDaysUntil:(NSDate *)date;

@end
