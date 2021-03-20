#import "GCWCalendarEvent.h"

#import <Foundation/NSDate.h>
#import "NSString+GCWSmartIcon.h"
#import "NSDate+GCWDate.h"
#import "NSDateFormatter+GCWDateFormatter.h"

@implementation GCWCalendarEvent

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self != nil) {
        NSString *jsonString = [coder decodeObjectForKey:@"GCWCalendarEventJSON"];
        NSError *jsonError;
        NSData *objectData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                              options:NSJSONReadingMutableContainers
                                                error:&jsonError];
        if (!jsonError) {
            GCWCalendarEvent *event = [[self class] objectWithJSON:json];
            event.calendarId = [coder decodeObjectForKey:@"GCWCalendarEventId"];
            event.color = [coder decodeObjectForKey:@"GCWCalendarEventColor"];
            event.isImportant = [coder decodeBoolForKey:@"GCWCalendarEventImportanceFlag"];
            return event;
        }
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:[self JSONString] forKey:@"GCWCalendarEventJSON"];
    [coder encodeObject:self.calendarId forKey:@"GCWCalendarEventId"];
    [coder encodeObject:self.color forKey:@"GCWCalendarEventColor"];
    [coder encodeBool:self.isImportant forKey:@"GCWCalendarEventImportanceFlag"];
}

- (instancetype)initWithGTLCalendarEvent:(GTLRCalendar_Event *)event {
    return [[self class] objectWithJSON:event.JSON];
}

- (BOOL)isAllDay {
    return self.start && !self.start.dateTime && !self.end.dateTime && [self.endDate timeIntervalSinceDate:self.startDate] == 86400;
}

- (NSDate *)startDateDayOnly {
    return self.startDate.dayOnly;
}

- (NSString *)startTimeString {
    return [[NSDateFormatter dayHourFormatter] stringFromDate:self.start.dateTime.date] ? : @"";
}

- (NSString *)durationString {
    NSDate *endDate = self.end.dateTime.date;
    NSDate *startDate = self.start.dateTime.date;
    NSTimeInterval minutesBetweenDates = [endDate timeIntervalSinceDate:startDate] / 60;

    NSInteger minutes = @(minutesBetweenDates).integerValue % 60;
    NSInteger hours = minutesBetweenDates / 60;

    NSString *durationString;
    if (!self.start.dateTime.date) {
        durationString = @"1d";
    } else if (!hours || !minutes) {
        durationString = [NSString stringWithFormat:@"%@%@", !hours ? @(minutes) : @(hours), !hours ? @"m" : @"h"];
    } else {
        durationString = [NSString stringWithFormat:@"%@h %@m", @(hours), @(minutes)];
    }

    return durationString;
}

- (NSTimeInterval)timeIntervalSinceEpochTime {
    return [self.startDate timeIntervalSince1970];
}

- (NSDate *)startDate {
    return self.start.dateTime.date ? : self.start.date.date;
}

- (void)setStartDate:(NSDate *)startDate {
    // Include an offset minutes that tells Google Calendar that these datesa
    // are for the local time zone.
    NSInteger offsetMinutes = [NSTimeZone localTimeZone].secondsFromGMT / 60;
    NSTimeInterval durationInMinutes = [self.end.dateTime.date timeIntervalSinceDate:startDate] / 60;

    if (durationInMinutes ==  kAllDayDuration) {
        self.start.date = [GTLRDateTime dateTimeForAllDayWithDate:startDate];
        self.start.dateTime = nil;
        self.end.date = [GTLRDateTime dateTimeForAllDayWithDate:self.end.dateTime.date];
        self.end.dateTime = nil;
    } else {
        self.start.date = nil;
        self.start.dateTime = [GTLRDateTime dateTimeWithDate:startDate offsetMinutes:offsetMinutes];
    }
    self.start.timeZone = [NSCalendar currentCalendar].timeZone.name;
}

- (NSString *)startDateIfInNext30MinutesString {
    NSInteger timeIntervalSinceNowInMinute = [self.startDate timeIntervalSinceNow] / 60;
    if (timeIntervalSinceNowInMinute >= 0 && timeIntervalSinceNowInMinute < 30 && [self.startDate timeIntervalSinceNow] > 0) {
        if (timeIntervalSinceNowInMinute == 0) {
            return @"Now";
        } else {
            return [NSString stringWithFormat:@"In %@ min", @(timeIntervalSinceNowInMinute)];
        }
    } else {
        return nil;
    }
}

- (NSDate *)endDate {
    return self.end.dateTime.date ? : self.end.date.date;
}

- (void)setEndDate:(NSDate *)endDate {
    // Include an offset minutes that tells Google Calendar that these datesa
    // are for the local time zone.
    NSInteger offsetMinutes = [NSTimeZone localTimeZone].secondsFromGMT / 60;
    NSTimeInterval durationInMinutes = [endDate timeIntervalSinceDate:self.start.dateTime.date] / 60;

    if (durationInMinutes ==  kAllDayDuration) {
        self.start.date = [GTLRDateTime dateTimeForAllDayWithDate:self.start.dateTime.date];
        self.start.dateTime = nil;
        self.end.date = [GTLRDateTime dateTimeForAllDayWithDate:endDate];
        self.end.dateTime = nil;
    } else {
        self.end.date = nil;
        self.end.dateTime = [GTLRDateTime dateTimeWithDate:endDate offsetMinutes:offsetMinutes];
    }
    self.end.timeZone = [NSCalendar currentCalendar].timeZone.name;
}

- (NSString *)endTimeString {
    return [[NSDateFormatter dayHourFormatter] stringFromDate:self.end.dateTime.date] ? : @"";
}

- (GTLRCalendar_EventAttendee *)selfAsAttendee {
    for (GTLRCalendar_EventAttendee *attendee in self.attendees) {
        if (attendee.selfProperty.boolValue) {
            return attendee;
        }
    }

    return nil;
}

- (GCWCalendarEventResponseStatus)responseStatus {
    NSString *responseStatusString = self.selfAsAttendee.responseStatus;

    if ([responseStatusString isEqualToString:@"needsAction"]) {
        return GCWCalendarEventResponseStatusNeedsAction;
    } else if ([responseStatusString isEqualToString:@"declined"]) {
        return GCWCalendarEventResponseStatusDeclined;
    } else if ([responseStatusString isEqualToString:@"tentative"]) {
        return GCWCalendarEventResponseStatusTentative;
    } else if ([responseStatusString isEqualToString:@"accepted"]) {
        return GCWCalendarEventResponseStatusAccepted;
    }

    return GCWCalendarEventResponseStatusUnknown;
}

- (NSString *)iconName {
    return self.summary.matchIconName;
}


- (NSString *)videoConferenceURI {
    if (self.conferenceData.entryPoints.count > 0) {
        for (GTLRCalendar_EntryPoint *entryPoint in self.conferenceData.entryPoints) {
            if ([entryPoint.entryPointType isEqualToString:@"video"]) {
                return entryPoint.uri;
            }
        }
    }
    return nil;
}

- (BOOL)hasAttendeeWithEmail:(NSString *)email {
    BOOL found = NO;
    for (GTLRCalendar_EventAttendee *attendee in self.attendees) {
        if ([attendee.email isEqualToString:email]) {
            found = YES;
            break;
        }
    }
    return found;
}

- (NSArray *)attendeesEmailAddresses {
    NSMutableArray *attendeeEmails = [NSMutableArray array];
    for(GTLRCalendar_EventAttendee *attendee in self.attendees) {
        if (attendee.email.length) {
            [attendeeEmails addObject:attendee.email];
        }
    }
    return attendeeEmails;
}

- (void)setAttendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses {
    NSMutableArray *attendees = [NSMutableArray arrayWithArray:self.attendees];
    for (NSString *email in attendeesEmailAddresses) {
        if (![self hasAttendeeWithEmail:email]) {
            GTLRCalendar_EventAttendee *attendee = [[GTLRCalendar_EventAttendee alloc] init];
            attendee.email = email;
            [attendees addObject:attendee];
        }
    }
    self.attendees = attendees;
}

- (BOOL)isRecurring {
    return self.recurrence.count || self.recurringEventId.length;
}

- (NSNumber *)notificationPeriod {
    NSArray *notifications = self.reminders.overrides;

    if (notifications == nil) {
        return nil;
    }
    for (GTLRCalendar_EventReminder *notification in notifications) {
        if ([notification.method isEqualToString:@"popup"]) {
            NSNumber *minutes = notification.minutes;
            return minutes;
        }
    }
    return 0;
}

- (void)setNotificationPeriod:(NSNumber *)notificationPeriod {
    NSArray *notifications = self.reminders.overrides;

    if (notifications == nil && notificationPeriod == nil) {
        return;
    }
    if (notifications == nil) {
        GTLRCalendar_EventReminder *notification = [[GTLRCalendar_EventReminder alloc] init];
        notification.method = @"popup";
        notification.minutes = notificationPeriod;
        self.reminders.overrides = @[notification];
        return;
    }
    if (notificationPeriod == nil) {
        self.reminders.overrides = @[];
    } else {
        for (GTLRCalendar_EventReminder *notification in notifications) {
            if ([notification.method isEqualToString:@"popup"]) {
                notification.minutes = notificationPeriod;
            }
        }
    }
}

@end
