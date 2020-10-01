#import "GCWCalendarEvent.h"

#import <Foundation/NSDate.h>
#import "NSString+GCWSmartIcon.h"
#import "NSDate+GCWDate.h"
#import "NSDateFormatter+GCWDateFormatter.h"

@implementation GCWCalendarEvent

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

@end
