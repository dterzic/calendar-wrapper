#import "GCWCalendar.h"
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

static NSString *const kIssuerURI = @"https://accounts.google.com";
static NSString *const kUserInfoURI = @"https://www.googleapis.com/oauth2/v3/userinfo";
static NSString *const kRedirectURI = @"com.googleusercontent.apps.48568066200-or08ed9efloks9ci5494f8jmcogucg1t:/oauthredirect";
static NSString *const kCalendarWrapperAuthorizerKey = @"googleOAuthCodingKeyForCalendarWrapper";
static NSString *const kUserIDs = @"googleUserIDsKey";
static NSString *const kOIDAuthorizationCalendarScope = @"https://www.googleapis.com/auth/calendar";

@interface GCWCalendar ()

@property (nonatomic) NSString *clientId;
@property (nonatomic) UIViewController *presentingViewController;
@property (nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;

@end

@implementation GCWCalendar

- (instancetype)initWithClientId:(NSString *)clientId
        presentingViewController:(UIViewController *)viewController
                        delegate:(id<GCWCalendarDelegate>)delegate {
    self = [super init];

    if (self) {
        _calendarService = [[GTLRCalendarService alloc] init];
        _calendarService.shouldFetchNextPages = true;
        _calendarService.retryEnabled = true;

        self.clientId = clientId;
        self.presentingViewController = viewController;
        self.delegate = delegate;
    }
    return self;
}

- (void)loadAuthorizationsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
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
            [self checkIfAuthorizationIsValid:authorization success:^{
                [self saveAuthorization:authorization toKeychain:keychainKey];
                validationCompleted();

            } failure:^(NSError *error) {
                // OIDOAuthTokenErrorDomain indicates an issue with the authorization.
                if ([error.domain isEqual:OIDOAuthTokenErrorDomain]) {
                    NSLog(@"EmailHelper: Authorization error during token refresh, cleared state. %@", error);
                    [self removeAuthorization:authorization fromKeychain:[self getKeychainKeyForAuthorization:authorization]];
                } else {
                    // Other errors are assumed transient.
                    NSLog(@"EmailHelper: Transient error during token refresh. %@", error);
                    [self saveAuthorization:authorization toKeychain:keychainKey];
                }
                validationCompleted();
            }];
        } else {
            [self removeAuthorization:authorization fromKeychain:keychainKey];
        }
    }];
}

- (void)saveAuthorizations {
    NSMutableArray *userIDs = [NSMutableArray array];
    [self.authorizations enumerateObjectsUsingBlock:^(GTMAppAuthFetcherAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        [userIDs addObject: authorization.userID];
    }];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userIDs forKey:kUserIDs];
    [defaults synchronize];
}

- (void)doLoginOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    NSURL *issuer = [NSURL URLWithString:kIssuerURI];
    NSURL *redirectURI = [NSURL URLWithString:kRedirectURI];

    NSLog(@"EmailHelper: Fetching configuration for issuer: %@", issuer);

    // discovers endpoints
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer completion:^(OIDServiceConfiguration *_Nullable configuration, NSError *_Nullable error) {
        if (!configuration) {
            NSLog(@"EmailHelper: Error retrieving discovery document: %@", [error localizedDescription]);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
            return;
        }

        NSLog(@"EmailHelper: Got configuration: %@", configuration);

        // builds authentication request
        OIDAuthorizationRequest *request =
        [[OIDAuthorizationRequest alloc] initWithConfiguration:configuration
                                                      clientId:self.clientId
                                                        scopes:@[OIDScopeOpenID, OIDScopeProfile, kOIDAuthorizationCalendarScope,  @"https://mail.google.com/"]
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
        // performs authentication request
        NSLog(@"EmailHelper: Initiating authorization request with scope: %@", request.scope);
        self.currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.presentingViewController
                                                       callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
            if (authState) {
                GTMAppAuthFetcherAuthorization *authorization = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
                [self saveAuthorization:authorization toKeychain:[self getKeychainKeyForAuthorization:authorization]];

                dispatch_async(dispatch_get_main_queue(), success);
            } else {
                NSLog(@"EmailHelper: Authorization error: %@", [error localizedDescription]);
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

- (void)checkIfAuthorizationIsValid:(GTMAppAuthFetcherAuthorization *)authorization
                            success:(void (^)(void))success
                            failure:(void (^)(NSError *))failure {
    // Creates a GTMSessionFetcherService with the authorization.
    // Normally you would save this service object and re-use it for all REST API calls.
    GTMSessionFetcherService *fetcherService = [[GTMSessionFetcherService alloc] init];
    NSURL *userinfoEndpoint = [NSURL URLWithString:kUserInfoURI];
    GTMSessionFetcher *fetcher = [fetcherService fetcherWithURL:userinfoEndpoint];

    [fetcher beginFetchWithCompletionHandler:^(NSData *data, NSError *error) {
        if (error) {
            failure(error);
        } else {
            success();
        }
        return;
    }];
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

- (void)loadCalendarLists:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure {
    NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
    [self.authorizations enumerateObjectsUsingBlock:^(GTMAppAuthFetcherAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        [self loadCalendarListForAuthorization:authorization success:^(NSDictionary *accountCalendars) {
            [accountCalendars enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                [calendars setValue:obj forKey:key];
            }];
            success(calendars);
        } failure:^(NSError *error) {
            failure(error);
            *stop = YES;
        }];
    }];
}

- (void)loadCalendarListForAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                                 success:(void (^)(NSDictionary *))success
                                 failure:(void (^)(NSError *))failure {
    self.calendarService.authorizer = authorization;
    GTLRCalendarQuery_CalendarListList *query = [GTLRCalendarQuery_CalendarListList query];
    query.minAccessRole = kGTLRCalendarMinAccessRoleOwner;
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
            GTLRCalendar_CalendarList *list = object;
            [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_CalendarListEntry * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                calendars[obj.identifier] = obj;
            }];
            success(calendars.copy);
        }
    }];
}

- (void)getEventsListForAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
                         fromCalendar:(NSString *)calendarId
                            startDate:(NSDate *)startDate
                              endDate:(NSDate *)endDate
                           maxResults:(NSUInteger)maxResults
                              success:(void (^)(NSDictionary *))success
                              failure:(void (^)(NSError *))failure {
    
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
                events[obj.identifier] = obj;
            }];
            success(events.copy);
        }
    }];
}

- (void)addEvent:(GTLRCalendar_Event *)event
forAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
      toCalendar:(NSString *)calendarId
         success:(void (^)(NSString *))success
         failure:(void (^)(NSError *))failure {

    GTLRCalendarQuery_EventsInsert *query = [GTLRCalendarQuery_EventsInsert queryWithObject:event calendarId:calendarId];
    self.calendarService.authorizer = authorization;
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
   forAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {

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

- (void)updateEvent:(GTLRCalendar_Event *)event
   forAuthorization:(GTMAppAuthFetcherAuthorization *)authorization
         inCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {
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
