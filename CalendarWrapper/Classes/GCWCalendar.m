#import "GCWCalendar.h"

@implementation GCWCalendar

- (instancetype)initWithClientId:(NSString *)clientId {
    self = [super init];

    if (self) {
        _calendarService = [[GTLRCalendarService alloc] init];
        _calendarService.shouldFetchNextPages = true;
        _calendarService.retryEnabled = true;

        [GIDSignIn sharedInstance].clientID = clientId;
        [GIDSignIn sharedInstance].delegate = self;

        [self silentSignin];
    }
    return self;
}

+ (GTLRCalendar_Event *)createEventWithTitle:(NSString *)title
                                    location:(NSString *)location
                                 description:(NSString *)description
                                        date:(NSDate *)date
                                    duration:(NSInteger)duration {
    // Make a new event, and show it to the user to edit
    GTLRCalendar_Event *newEvent = [GTLRCalendar_Event object];

    newEvent.summary = title;
    newEvent.location = location;
    newEvent.descriptionProperty = description;

    NSDate *startDate = date;
    NSDate *endDate = [NSDate dateWithTimeInterval:(duration * 60) sinceDate:startDate];

    // Include an offset minutes that tells Google Calendar that these datesa
    // are for the local time zone.
    NSInteger offsetMinutes = [NSTimeZone localTimeZone].secondsFromGMT / 60;

    GTLRDateTime *startDateTime = [GTLRDateTime dateTimeWithDate:startDate offsetMinutes:offsetMinutes];
    GTLRDateTime *endDateTime = [GTLRDateTime dateTimeWithDate:endDate offsetMinutes:offsetMinutes];

    newEvent.start = [GTLRCalendar_EventDateTime object];
    newEvent.start.dateTime = startDateTime;

    newEvent.end = [GTLRCalendar_EventDateTime object];
    newEvent.end.dateTime = endDateTime;

    GTLRCalendar_EventReminder *reminder = [GTLRCalendar_EventReminder object];
    reminder.minutes = @10;
    reminder.method = @"popup";

    newEvent.reminders = [GTLRCalendar_Event_Reminders object];
    newEvent.reminders.overrides = @[ reminder ];
    newEvent.reminders.useDefault = @NO;

    return newEvent;
}

+ (NSError *)createErrorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    return [NSError errorWithDomain:@"com.calendar-wrapper" code:code userInfo:userInfo];
}

- (BOOL)silentSignin {
    [[GIDSignIn sharedInstance] setScopes:@[@"https://www.googleapis.com/auth/calendar"]];

    if ([GIDSignIn sharedInstance].hasAuthInKeychain) {
        [[GIDSignIn sharedInstance] signInSilently];
        return true;
    } else {
        if ([self.delegate respondsToSelector:@selector(calendarLoginRequired:)]) {
            [self.delegate calendarLoginRequired:self];
        }
        return false;
    }
}

- (void)loadCalendarList:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure {
    self.calendarService.authorizer = [GIDSignIn sharedInstance].currentUser.authentication.fetcherAuthorizer;
    GTLRCalendarQuery_CalendarListList *query = [GTLRCalendarQuery_CalendarListList query];
    query.minAccessRole = kGTLRCalendarMinAccessRoleOwner;
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
            GTLRCalendar_CalendarList *list = object;
            [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_CalendarListEntry * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                calendars[obj.identifier] = obj.summary;
            }];
            success(calendars.copy);
        }
    }];
}

- (void)addEvent:(GTLRCalendar_Event *)event
      toCalendar:(NSString *)calendarId
         success:(void (^)(NSString *))success
         failure:(void (^)(NSError *))failure {

    GTLRCalendarQuery_EventsInsert *query = [GTLRCalendarQuery_EventsInsert queryWithObject:event calendarId:calendarId];
    self.calendarService.authorizer = [GIDSignIn sharedInstance].currentUser.authentication.fetcherAuthorizer;
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         GTLRCalendar_Event *event,
                                         NSError *callbackError) {
                         if (callbackError == nil) {
                             success(event.identifier);
                         } else {
                             failure(callbackError);
                         }
                     }];
}

- (void)deleteEvent:(NSString *)eventId
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {

    GTLRCalendarQuery_EventsDelete *query = [GTLRCalendarQuery_EventsDelete
                                             queryWithCalendarId:calendarId
                                             eventId:eventId];
    self.calendarService.authorizer = [GIDSignIn sharedInstance].currentUser.authentication.fetcherAuthorizer;
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         id nilObject,
                                         NSError *callbackError) {
                         // Callback
                         if (callbackError == nil) {
                             success();
                         } else {
                             failure(callbackError);
                         }
                     }];
}

// GCWCalendarDelegate

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(calendar:didSignInForUser:withError:)]) {
        [self.delegate calendar:self didSignInForUser:user withError:error];
    }
}

- (void)signIn:(GIDSignIn *)signIn didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(calendar:didDisconnectWithUser:withError:)]) {
        [self.delegate calendar:self didDisconnectWithUser:user withError:error];
    }
}

@end
