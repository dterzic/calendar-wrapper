#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

static NSInteger const kAllDayDuration = 24 * 60;

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
@property (nonatomic, readonly) BOOL isAllDay;
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
@property (nonatomic, readonly) NSString *conferenceName;
@property (nonatomic, readonly) NSString *conferenceIconUri;
@property (nonatomic, readonly) NSString *conferenceVideoId;
@property (nonatomic, readonly) NSString *conferenceVideoUri;
@property (nonatomic, readonly) NSString *conferencePhoneNumber;
@property (nonatomic, readonly) NSString *conferenceFormattedPhoneNumber;
@property (nonatomic, readonly) NSString *conferenceInfoUri;

@property (nonatomic) NSArray< NSString *> *attendeesEmailAddresses;
@property (nonatomic) BOOL isImportant;
@property (nonatomic, readonly) BOOL isRecurring;
@property (nonatomic) NSNumber *notificationPeriod;

- (BOOL)hasAttendeeWithEmail:(NSString *)email;
- (GTLRCalendar_EventAttendee *)getAttendeeWithEmail:(NSString *)email;

@end

NS_ASSUME_NONNULL_END
