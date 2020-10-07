#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, GCWCalendarEventResponseStatus) {
    GCWCalendarEventResponseStatusNeedsAction,
    GCWCalendarEventResponseStatusDeclined,
    GCWCalendarEventResponseStatusTentative,
    GCWCalendarEventResponseStatusAccepted,
    GCWCalendarEventResponseStatusUnknown
};

@interface GCWCalendarEvent : GTLRCalendar_Event

- (instancetype)initWithGTLCalendarEvent:(GTLRCalendar_Event *)event;

@property (nonatomic) UIColor *color;
@property (nonatomic) NSString *calendarId;
@property (nonatomic, readonly) NSString *iconName;
@property (nonatomic) NSDate *startDate;
@property (nonatomic, readonly) NSString *startDateIfInNext30MinutesString;
@property (nonatomic, readonly) NSDate *startDateDayOnly;
@property (nonatomic, readonly) NSString *startTimeString;
@property (nonatomic) NSDate *endDate;
@property (nonatomic, readonly) NSString *endTimeString;
@property (nonatomic, readonly) NSString *durationString;
@property (nonatomic, readonly) NSTimeInterval timeIntervalSinceEpochTime;
@property (nonatomic, readonly) GTLRCalendar_EventAttendee *selfAsAttendee;
@property (nonatomic, readonly) GCWCalendarEventResponseStatus responseStatus;
@property (nonatomic, readonly) NSString *videoConferenceURI;

@property (nonatomic) BOOL isImportant;

@end

NS_ASSUME_NONNULL_END
