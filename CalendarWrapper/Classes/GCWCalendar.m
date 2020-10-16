#import "GCWCalendar.h"

#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWUserAccount.h"

#import "NSDictionary+GCWCalendar.h"
#import "NSDictionary+GCWCalendarEvent.h"
#import "UIColor+MNTColor.h"

static NSString *const kIssuerURI = @"https://accounts.google.com";
static NSString *const kUserInfoURI = @"https://www.googleapis.com/oauth2/v3/userinfo";
static NSString *const kRedirectURI = @"com.googleusercontent.apps.350629588452-bcbi20qrl4tsvmtia4ps4q16d8i9sc4l:/oauthredirect";
static NSString *const kCalendarWrapperAuthorizerKey = @"googleOAuthCodingKeyForCalendarWrapper";
static NSString *const kUserIDs = @"googleUserIDsKey";
static NSString *const kOIDAuthorizationCalendarScope = @"https://www.googleapis.com/auth/calendar";
static NSString *const kCalendarEventsKey = @"calendarWrapperCalendarEventsKey";
static NSString *const kCalendarEntriesKey = @"calendarWrapperCalendarEntriesKey";
static NSString *const kCalendarSyncTokensKey = @"calendarWrapperCalendarSyncTokensKey";

@interface GCWCalendar ()

@property (nonatomic) NSString *clientId;
@property (nonatomic) UIViewController *presentingViewController;
@property (nonatomic) NSMutableDictionary *calendarUsers;
@property (nonatomic) NSMutableDictionary *calendarSyncTokens;

@end

@implementation GCWCalendar

- (instancetype)initWithClientId:(NSString *)clientId
        presentingViewController:(UIViewController *)viewController {
    self = [super init];

    if (self) {
        _calendarService = [[GTLRCalendarService alloc] init];
        _calendarService.shouldFetchNextPages = true;
        _calendarService.retryEnabled = true;

        NSDictionary *entriesArchive = [[NSUserDefaults standardUserDefaults] objectForKey:kCalendarEntriesKey];
        if (entriesArchive) {
            _calendarEntries = [NSDictionary unarchiveCalendarEntriesFrom:entriesArchive];
        }
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kCalendarEventsKey];
        NSArray *eventsArchive = [NSArray arrayWithContentsOfFile:filePath];
        if (eventsArchive) {
            _calendarEvents = [NSMutableDictionary dictionaryWithDictionary:[NSDictionary unarchiveCalendarEventsFrom:eventsArchive]];
        } else {
            _calendarEvents = [NSMutableDictionary dictionary];
        }
        NSDictionary *calendarSyncTokens = [[NSUserDefaults standardUserDefaults] objectForKey:kCalendarSyncTokensKey];
        if (calendarSyncTokens) {
            self.calendarSyncTokens = [NSMutableDictionary dictionaryWithDictionary:calendarSyncTokens];
        } else {
            self.calendarSyncTokens = [NSMutableDictionary dictionary];
        }
        NSLog(@"LOADED: %lu calendars and %lu events.", (unsigned long)self.calendarEntries.count, (unsigned long)self.calendarEvents.count);

        self.clientId = clientId;
        self.presentingViewController = viewController;
    }
    return self;
}

- (NSString *)getCalendarOwner:(NSString *)calendarId {
    return self.calendarUsers[calendarId];
}

- (NSDictionary <NSString *, NSArray<GCWCalendarEntry *> *> *)accountEntries {
    NSMutableDictionary *accountEntries = [NSMutableDictionary dictionary];
    for (NSString *userID in self.userAccounts.allKeys) {
        [accountEntries setValue:[NSMutableArray array] forKey:userID];
    }
    for (GCWCalendarEntry *entry in self.calendarEntries.allValues) {
        GTMAppAuthFetcherAuthorization *calendarAuthorization = [self getAuthorizationForCalendar:entry.identifier];
        NSMutableArray *entries = [accountEntries valueForKey:calendarAuthorization.userID];
        [entries addObject:entry];
    }
    return [accountEntries copy];
}

- (NSString *)encodedUserInfoFor:(NSError *)error {
    return [[NSString alloc] initWithData:error.userInfo[@"data"] encoding:NSUTF8StringEncoding];
}

- (void)loadAuthorizationsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    self.userAccounts = [NSMutableDictionary dictionary];
    self.authorizations = [NSMutableArray array];
    NSArray *userIDs = [[NSUserDefaults standardUserDefaults] arrayForKey:kUserIDs];

    if (!userIDs || userIDs.count == 0) {
        failure([NSError errorWithDomain:@"CalendarWrapperErrorDomain"
                                    code:-10001
                                userInfo:@{NSLocalizedDescriptionKey:@"No valid authorization"}]);
        return;
    }

    __block NSUInteger count = userIDs.count;
    void (^validationCompleted)(void) = ^{
        count--;
        if (count == 0) {
            success();
        }
    };

    [userIDs enumerateObjectsUsingBlock:^(id  _Nonnull userID, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * keychainKey = [self getKeychainKeyForUser:userID];
        GTMAppAuthFetcherAuthorization* authorization = [self getAuthorizationFromKeychain:keychainKey];

        if (authorization.canAuthorize) {
            [self getUserInfoForAuthorization:authorization success:^(NSDictionary *userInfo) {
                NSString *userName = [userInfo valueForKey:@"name"];
                if (userName && ![self.userAccounts valueForKey:userID]) {
                    GCWUserAccount *account = [[GCWUserAccount alloc] initWithUserInfo:userInfo];
                    [self.userAccounts setValue:account forKey:userID];
                }
                [self saveAuthorization:authorization toKeychain:keychainKey];
                validationCompleted();

            } failure:^(NSError *error) {
                // OIDOAuthTokenErrorDomain indicates an issue with the authorization.
                if ([error.domain isEqual:OIDOAuthTokenErrorDomain]) {
                    NSLog(@"CalendarWrapper: Authorization error during token refresh, cleared state. %@", [self encodedUserInfoFor:error]);
                    [self removeAuthorization:authorization fromKeychain:[self getKeychainKeyForAuthorization:authorization]];
                } else {
                    // Other errors are assumed transient.
                    NSLog(@"CalendarWrapper: Transient error during token refresh. %@", [self encodedUserInfoFor:error]);
                    [self saveAuthorization:authorization toKeychain:keychainKey];
                }
                validationCompleted();
            }];
        } else {
            [self removeAuthorization:authorization fromKeychain:keychainKey];
            validationCompleted();
        }
    }];
}

- (void)saveState {
    NSMutableArray *userIDs = [NSMutableArray array];
    [self.authorizations enumerateObjectsUsingBlock:^(GTMAppAuthFetcherAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        [userIDs addObject: authorization.userID];
    }];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userIDs forKey:kUserIDs];
    [defaults setObject:self.calendarSyncTokens forKey:kCalendarSyncTokensKey];
    [defaults setObject:[self.calendarEntries archiveCalendarEntries] forKey:kCalendarEntriesKey];
    [defaults synchronize];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kCalendarEventsKey];
    NSArray *archive = [self.calendarEvents archiveCalendarEvents];
    [archive writeToFile:filePath atomically:YES];

    NSLog(@"SAVED: %lu users, %lu calendars and %lu events.", (unsigned long)userIDs.count, (unsigned long)self.calendarEntries.count, (unsigned long)self.calendarEvents.count);
}

- (void)doLoginOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    NSURL *issuer = [NSURL URLWithString:kIssuerURI];
    NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];

    NSLog(@"CalendarWrapper: Fetching configuration for issuer: %@", issuer);

    // discovers endpoints
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {
        if (!configuration) {
            NSLog(@"CalendarWrapper: Error retrieving discovery document: %@", [self encodedUserInfoFor:error]);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
            return;
        }

        // builds authentication request
        OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:self.clientId
                                                        scopes:@[OIDScopeOpenID, OIDScopeProfile, kOIDAuthorizationCalendarScope]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
        // performs authentication request
        self.currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.presentingViewController
                                                       callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
            if (authState) {
                GTMAppAuthFetcherAuthorization *authorization = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
                [self saveAuthorization:authorization toKeychain:[self getKeychainKeyForAuthorization:authorization]];
                [self getUserInfoForAuthorization:authorization success:^(NSDictionary *userInfo) {
                    NSString *userName = [userInfo valueForKey:@"name"];
                    if (userName && ![self.userAccounts valueForKey:authorization.userID]) {
                        GCWUserAccount *account = [[GCWUserAccount alloc] initWithUserInfo:userInfo];
                        [self.userAccounts setValue:account forKey:authorization.userID];
                    }
                    dispatch_async(dispatch_get_main_queue(), success);
                } failure:^(NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        failure(error);
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    failure(error);
                });
            }
        }];
    }];
}

- (void)saveAuthorization:(GTMAppAuthFetcherAuthorization *)authorization toKeychain:(NSString *)keychainKey {
    [GTMAppAuthFetcherAuthorization saveAuthorization:authorization toKeychainForName:keychainKey];
    [self.authorizations addObject:authorization];
}

- (void)removeAuthorization:(GTMAppAuthFetcherAuthorization *)authorization fromKeychain:(NSString *)keychainKey {
    [GTMAppAuthFetcherAuthorization removeAuthorizationFromKeychainForName:keychainKey];
    [self.authorizations removeObject:authorization];
}

- (GTMAppAuthFetcherAuthorization *)getAuthorizationFromKeychain:(NSString *)keychainKey {
    return [GTMAppAuthFetcherAuthorization authorizationFromKeychainForName:keychainKey];
}

- (NSString *)getKeychainKeyForAuthorization:(GTMAppAuthFetcherAuthorization *)authorization {
    return [NSString stringWithFormat:@"%@_%@", kCalendarWrapperAuthorizerKey, authorization.userID];
}

- (NSString *)getKeychainKeyForUser:(NSString *)userID {
    return [NSString stringWithFormat:@"%@_%@", kCalendarWrapperAuthorizerKey, userID];
}

- (GTMAppAuthFetcherAuthorization *)getAuthorizationForCalendar:(NSString *)calendarId {
    __block GTMAppAuthFetcherAuthorization *calendarAuthorization = nil;
    NSString *userId = self.calendarUsers[calendarId];
    [self.authorizations enumerateObjectsUsingBlock:^(GTMAppAuthFetcherAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        if (authorization.userID == userId) {
            calendarAuthorization = authorization;
            *stop = YES;
        }
    }];
    return calendarAuthorization;
}

- (void)getUserInfoForAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                                      success:(void (^)(NSDictionary *))success
                                      failure:(void (^)(NSError *))failure {
    GTMSessionFetcherService *fetcherService = [[GTMSessionFetcherService alloc] init];
    fetcherService.authorizer = authorization;
    NSURL *userinfoEndpoint = [NSURL URLWithString:kUserInfoURI];
    GTMSessionFetcher *fetcher = [fetcherService fetcherWithURL:userinfoEndpoint];

    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error) {
            failure(error);
        } else {
            NSError *jsonError = nil;
            NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                failure(jsonError);
            }
            success(userInfo);
        }
        return;
    }];
}

+ (GCWCalendarEvent *)createEventWithTitle:(NSString *)title
                                  location:(NSString *)location
                   attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
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

    newEvent.start = [GTLRCalendar_EventDateTime object];
    if (duration == kAllDayDuration) {
        GTLRDateTime *startDateTime = [GTLRDateTime dateTimeForAllDayWithDate:startDate];
        newEvent.start.date = startDateTime;
    } else {
        GTLRDateTime *startDateTime = [GTLRDateTime dateTimeWithDate:startDate offsetMinutes:offsetMinutes];
        newEvent.start.dateTime = startDateTime;
    }
    newEvent.start.timeZone = [NSCalendar currentCalendar].timeZone.name;

    newEvent.end = [GTLRCalendar_EventDateTime object];
    if (duration == kAllDayDuration) {
        GTLRDateTime *endDateTime = [GTLRDateTime dateTimeForAllDayWithDate:endDate];
        newEvent.end.date = endDateTime;
    } else {
        GTLRDateTime *endDateTime = [GTLRDateTime dateTimeWithDate:endDate offsetMinutes:offsetMinutes];
        newEvent.end.dateTime = endDateTime;
    }
    newEvent.end.timeZone = [NSCalendar currentCalendar].timeZone.name;

    GTLRCalendar_EventReminder *reminder = [GTLRCalendar_EventReminder object];
    reminder.minutes = @10;
    reminder.method = @"popup";

    newEvent.reminders = [GTLRCalendar_Event_Reminders object];
    newEvent.reminders.overrides = @[ reminder ];
    newEvent.reminders.useDefault = @NO;

    NSMutableArray *attendees = [NSMutableArray array];
    for(NSString *email in attendeesEmailAddresses) {
        GTLRCalendar_EventAttendee *attendee = [[GTLRCalendar_EventAttendee alloc] init];
        attendee.email = email;
        [attendees addObject:attendee];
    }
    newEvent.attendees = attendees;

    return [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:newEvent];
}

+ (GCWCalendarEvent *)cloneEvent:(GCWCalendarEvent *)event {
    GCWCalendarEvent *clone = [[GCWCalendarEvent alloc] init];
    clone.calendarId = [event.calendarId copy];
    clone.start = [event.start copy];
    clone.end = [event.end copy];
    clone.summary = [event.summary copy];
    clone.location = [event.location copy];

    return clone;
}

+ (NSError *)createErrorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    return [NSError errorWithDomain:@"com.calendar-wrapper" code:code userInfo:userInfo];
}

- (void)loadCalendarListsForRole:(NSString *)accessRole
                         success:(void (^)(NSDictionary *))success
                         failure:(void (^)(NSError *))failure {
    NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
    self.calendarUsers = [NSMutableDictionary dictionary];

    __block NSUInteger authorizationIndex = 0;
    for (GTMAppAuthFetcherAuthorization *authorization in self.authorizations) {
        [self loadCalendarListForAuthorization:authorization accessRole:accessRole success:^(NSDictionary *accountCalendars) {
            [calendars addEntriesFromDictionary:accountCalendars];
            if (authorizationIndex == self.authorizations.count-1) {
                self.calendarEntries = [calendars copy];
                success(calendars);
            }
            authorizationIndex++;
        } failure:^(NSError *error) {
            failure(error);
            return;
        }];
    }
}

- (void)loadCalendarListForAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                              accessRole:(NSString *)accessRole
                                 success:(void (^)(NSDictionary *))success
                                 failure:(void (^)(NSError *))failure {
    self.calendarService.authorizer = authorization;
    GTLRCalendarQuery_CalendarListList *query = [GTLRCalendarQuery_CalendarListList query];
    query.minAccessRole = accessRole;
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
            GTLRCalendar_CalendarList *list = object;
            [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_CalendarListEntry * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                GCWCalendarEntry *calendar = [[GCWCalendarEntry alloc] initWithCalendarListEntry:obj];
                GCWCalendarEntry *cachedCalendar = self.calendarEntries[calendar.identifier];
                // Keep attribute value from cache
                if (cachedCalendar) {
                    calendar.hideEvents = cachedCalendar.hideEvents;
                }
                calendars[obj.identifier] = calendar;

                [self.calendarUsers setValue:authorization.userID forKey:calendar.identifier];

                // Set primary email address to user account
                if (calendar.primary.boolValue) {
                    GCWUserAccount *account = self.userAccounts[authorization.userID];
                    if (account) {
                        account.email = calendar.identifier;
                    }
                }
            }];
            success(calendars.copy);
        }
    }];
}

- (void)getEventForCalendar:(NSString *)calendarId
                    eventId:(NSString *)eventId
                    success:(void (^)(GCWCalendarEvent *))success
                    failure:(void (^)(NSError *))failure {

    GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([GCWCalendar createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization;

    GTLRCalendarQuery_EventsGet *query = [GTLRCalendarQuery_EventsGet queryWithCalendarId:calendarId eventId:eventId];
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:object];
            event.calendarId = calendarId;
            success(event);
        }
    }];
}

- (void)getEventsListForCalendar:(NSString *)calendarId
                       startDate:(NSDate *)startDate
                         endDate:(NSDate *)endDate
                      maxResults:(NSUInteger)maxResults
                         success:(void (^)(NSDictionary *))success
                         failure:(void (^)(NSError *))failure {

    GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([GCWCalendar createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization;

    GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendarId];
    if (maxResults > 0) {
        query.maxResults = maxResults;
    }
    query.singleEvents = true;
    query.timeMin = [GTLRDateTime dateTimeWithDate:startDate];
    query.timeMax = [GTLRDateTime dateTimeWithDate:endDate];
    query.orderBy = kGTLRCalendarOrderByStartTime;
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            NSMutableDictionary *events = [NSMutableDictionary dictionary];
            GTLRCalendar_Events *list = object;
            [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                events[event.identifier] = event;
            }];
            success(events.copy);
        }
    }];
}

- (void)syncEventsFrom:(NSDate *)startDate to:(NSDate *)endDate success:(void (^)(void))success failure:(void (^)(NSError *))failure {
    __block NSUInteger calendarIndex = 0;
    for (GCWCalendarEntry *calendar in self.calendarEntries.allValues) {
        GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendar.identifier];
        if (!authorization) {
            failure([GCWCalendar createErrorWithCode:-10002
                                         description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendar.identifier]]);
            return;
        }
        self.calendarService.authorizer = authorization;

        GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendar.identifier];
        query.maxResults = 2500;
        query.singleEvents = true;
        query.syncToken = self.calendarSyncTokens[calendar.identifier];
        [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                if (callbackError.code == 410) {
                    // In case token expire, remove it from cache
                    [self.calendarSyncTokens removeObjectForKey:calendar.identifier];
                }
                failure(callbackError);
            } else {
                GTLRCalendar_Events *list = object;
                [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (![obj.status isEqualToString:@"cancelled"]) {
                        GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];

                        if ([startDate compare:event.startDate] == NSOrderedAscending &&
                            [endDate compare:event.endDate] == NSOrderedDescending) {
                            event.calendarId = calendar.identifier;
                            event.color = [UIColor colorWithHex:calendar.backgroundColor];

                            // Keep attributes from cached object
                            GCWCalendarEvent *cachedEvent = self.calendarEvents[event.identifier];
                            if (cachedEvent) {
                                event.isImportant = cachedEvent.isImportant;
                            }
                            self.calendarEvents[event.identifier] = event;
                        }
                    }
                }];
                self.calendarSyncTokens[calendar.identifier] = [list nextSyncToken];
                if (calendarIndex == self.calendarEntries.count-1) {
                    success();
                }
                calendarIndex++;
            }
        }];
    }
}

- (void)addEvent:(GCWCalendarEvent *)event
      toCalendar:(NSString *)calendarId
         success:(void (^)(NSString *))success
         failure:(void (^)(NSError *))failure {

    GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([GCWCalendar createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization;

    GTLRCalendarQuery_EventsInsert *query = [GTLRCalendarQuery_EventsInsert queryWithObject:event calendarId:calendarId];
    self.calendarService.authorizer = authorization;
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         GTLRCalendar_Event *obj,
                                         NSError *callbackError) {
        GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
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

    GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([GCWCalendar createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization;

    GTLRCalendarQuery_EventsDelete *query = [GTLRCalendarQuery_EventsDelete
                                             queryWithCalendarId:calendarId
                                             eventId:eventId];
    self.calendarService.authorizer = authorization;
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         id nilObject,
                                         NSError *callbackError) {
                         if (callbackError == nil) {
                             success();
                         } else {
                             failure(callbackError);
                         }
                     }];
}

- (void)updateEvent:(GCWCalendarEvent *)event
         inCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {

    GTMAppAuthFetcherAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([GCWCalendar createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization;

    GTLRCalendarQuery_EventsUpdate *query = [GTLRCalendarQuery_EventsUpdate queryWithObject:event calendarId:calendarId eventId:event.identifier];
    self.calendarService.authorizer = authorization;
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         id nilObject,
                                         NSError *callbackError) {
                         if (callbackError == nil) {
                             success();
                         } else {
                             failure(callbackError);
                         }
                     }];
}

@end
