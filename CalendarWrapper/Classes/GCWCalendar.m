#import "GCWCalendar.h"

#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWCalendarAuthorizationManager.h"
#import "GCWCalendarAuthorization.h"
#import "GCWPerson.h"
#import "GCWUserAccount.h"
#import "GCWTaskList.h"
#import "GCWLoadEventsListRequest.h"

#import "NSDate+GCWDate.h"
#import "NSDateFormatter+GCWDateFormatter.h"
#import "NSDictionary+GCWCalendar.h"
#import "NSDictionary+GCWCalendarEvent.h"
#import "NSError+GCWCalendar.h"
#import "UIColor+MNTColor.h"

static NSString *const kIssuerURI = @"https://accounts.google.com";
static NSString *const kUserInfoURI = @"https://www.googleapis.com/oauth2/v3/userinfo";
static NSString *const kRedirectURI = @"com.googleusercontent.apps.235185111239-ubk6agijf4d4vq8s4fseradhn2g66r5s:/oauthredirect";
static NSString *const kUserIDs = @"googleUserIDsKey";
static NSString *const kCalendarEventsKey = @"calendarWrapperCalendarEventsKey";
static NSString *const kCalendarEntriesKey = @"calendarWrapperCalendarEntriesKey";
static NSString *const kCalendarSyncTokensKey = @"calendarWrapperCalendarSyncTokensKey";
static NSString *const kCalendarEventsNotificationPeriodKey = @"calendarWrapperCalendarEventsNotificationPeriodKey";

@interface GCWCalendar () <OIDAuthStateChangeDelegate>

@property (nonatomic) NSArray *authorizationScopes;
@property (nonatomic) NSString *clientId;
@property (nonatomic) UIViewController *presentingViewController;
@property (nonatomic) NSMutableDictionary *calendarUsers;
@property (nonatomic) NSUserDefaults *userDefaults;
@property (nonatomic) dispatch_queue_t eventsQueue;


@end

@implementation GCWCalendar

- (instancetype)initWithClientId:(NSString *)clientId
        presentingViewController:(UIViewController *)viewController
            authorizationManager:(id<CalendarAuthorizationProtocol>)authorizationManager
                    userDefaults:(NSUserDefaults *)userDefaults {
    self = [super init];

    if (self) {
        self.eventsQueue = dispatch_queue_create("com.moment.gcwcalendar.eventsqueue", DISPATCH_QUEUE_SERIAL);

        _authorizationScopes = @[OIDScopeOpenID,
                                 OIDScopeProfile,
                                 kGTLRAuthScopeCalendar,
                                 kGTLRAuthScopePeopleServiceContactsReadonly,
                                 kGTLRAuthScopePeopleServiceDirectoryReadonly,
                                 kGTLRAuthScopeTasks];

        _calendarService = [[GTLRCalendarService alloc] init];
        _calendarService.shouldFetchNextPages = true;
        _calendarService.retryEnabled = true;

        _peopleService = [[GTLRPeopleServiceService alloc] init];
        _tasksService = [[GTLRTasksService alloc] init];
        if (authorizationManager) {
            _authorizationManager = authorizationManager;
        } else {
            _authorizationManager = [[GCWCalendarAuthorizationManager alloc] init];
        }
        if (userDefaults) {
            _userDefaults = userDefaults;
        } else {
            _userDefaults = [NSUserDefaults standardUserDefaults];
        }
        _userAccounts = [NSMutableDictionary dictionary];

        NSDictionary *entriesArchive = [self.userDefaults objectForKey:kCalendarEntriesKey];
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
        NSDictionary *calendarSyncTokens = [self.userDefaults objectForKey:kCalendarSyncTokensKey];
        if (calendarSyncTokens) {
            self.calendarSyncTokens = [NSMutableDictionary dictionaryWithDictionary:calendarSyncTokens];
        } else {
            self.calendarSyncTokens = [NSMutableDictionary dictionary];
        }
        // Used for testing sync token expiration (error code 410)
        //self.calendarSyncTokens[@"amywei@envoy.com"] = [NSString stringWithFormat:@"1%@", self.calendarSyncTokens[@"amywei@envoy.com"]];
        
        NSNumber *notificationPeriod = [self.userDefaults objectForKey:kCalendarEventsNotificationPeriodKey];
        if (notificationPeriod) {
            self.notificationPeriod = notificationPeriod;
        } else {
            self.notificationPeriod = @(10);
        }
        NSLog(@"LOADED: %lu calendars and %lu events.", (unsigned long)self.calendarEntries.count, (unsigned long)eventsArchive.count);

        self.clientId = clientId;
        self.presentingViewController = viewController;
    }
    return self;
}

- (BOOL)calendarsInSync {
    __block BOOL status = YES;
    [self.calendarEntries enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        GCWCalendarEntry *calendar = (GCWCalendarEntry *)obj;
        NSString *syncToken = self.calendarSyncTokens[calendar.identifier];

        if (syncToken == nil) {
            *stop = YES;
            status = NO;
        }
    }];
    return status;

}

- (NSString *)getCalendarOwnerId:(NSString *)calendarId {
    return self.calendarUsers[calendarId];
}

- (GCWUserAccount *)getCalendarOwner:(NSString *)calendarId {
    NSString *userId = [self getCalendarOwnerId:calendarId];
    return self.userAccounts[userId];
}

- (BOOL)isAuthorizedFor:(GCWAuthorizationScope)scope {
    BOOL authorized = NO;

    authorized = [self checkAuthorizationForScope:OIDScopeOpenID] && [self checkAuthorizationForScope:OIDScopeProfile];
    if (scope == GCWAuthorizationScopeOpenId) {
        return authorized;
    }
    authorized = [self checkAuthorizationForScope:kGTLRAuthScopeCalendar];

    if (scope == GCWAuthorizationScopeCalendar) {
        return authorized;
    }
    authorized = [self checkAuthorizationForScope:kGTLRAuthScopePeopleServiceContacts] &&
                 [self checkAuthorizationForScope:kGTLRAuthScopePeopleServiceDirectoryReadonly];

    if (scope == GCWAuthorizationScopePeople) {
        return authorized;
    }
    authorized = [self checkAuthorizationForScope:kGTLRAuthScopeTasks];

    if (scope == GCWAuthorizationScopeTasks) {
        return authorized;
    }
}

- (BOOL)checkAuthorizationForScope:(NSString *)scope {
    NSArray *userIDs = [self.userDefaults arrayForKey:kUserIDs];

    if (!userIDs || userIDs.count == 0) {
        return NO;
    }
    __block BOOL authorized = YES;
    [userIDs enumerateObjectsUsingBlock:^(id  _Nonnull userID, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString * keychainKey = [GCWCalendarAuthorizationManager getKeychainKeyForUser:userID];

        if ([self.authorizationManager canAuthorizeWithAuthorizationFromKeychain:keychainKey]) {
            GCWCalendarAuthorization* authorization = [self.authorizationManager getAuthorizationFromKeychain:keychainKey];
            if (![authorization.fetcherAuthorization.authState.scope containsString:scope]) {
                authorized = NO;
                *stop = YES;
            }
        }
    }];
    return authorized;
}

- (NSDictionary <NSString *, NSArray<GCWCalendarEntry *> *> *)accountEntries {
    NSMutableDictionary *accountEntries = [NSMutableDictionary dictionary];
    for (NSString *userID in self.userAccounts.allKeys) {
        [accountEntries setValue:[NSMutableArray array] forKey:userID];
    }
    for (GCWCalendarEntry *entry in self.calendarEntries.allValues) {
        GCWCalendarAuthorization *calendarAuthorization = [self getAuthorizationForCalendar:entry.identifier];
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
    NSArray *userIDs = [self.userDefaults arrayForKey:kUserIDs];

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
        NSString * keychainKey = [GCWCalendarAuthorizationManager getKeychainKeyForUser:userID];

        if ([self.authorizationManager canAuthorizeWithAuthorizationFromKeychain:keychainKey]) {
            GCWCalendarAuthorization* authorization = [self.authorizationManager getAuthorizationFromKeychain:keychainKey];
            authorization.fetcherAuthorization.authState.stateChangeDelegate = self;

            [self loadUserInfoForAuthorization:authorization success:^(NSDictionary *userInfo) {
                NSString *userName = [userInfo valueForKey:@"name"];
                if (userName && ![self.userAccounts valueForKey:userID]) {
                    GCWUserAccount *account = [[GCWUserAccount alloc] initWithUserInfo:userInfo];
                    [self.userAccounts setValue:account forKey:userID];
                }
                [self.authorizationManager saveAuthorization:authorization toKeychain:keychainKey];
                validationCompleted();

            } failure:^(NSError *error) {
                // OIDOAuthTokenErrorDomain indicates an issue with the authorization.
                if ([error.domain isEqual:OIDOAuthTokenErrorDomain]) {
                    NSLog(@"CalendarWrapper: Authorization error during token refresh, cleared state. %@", [self encodedUserInfoFor:error]);
                    [self.authorizationManager removeAuthorization:authorization
                                                      fromKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];
                } else {
                    // Other errors are assumed transient.
                    NSLog(@"CalendarWrapper: Transient error during token refresh. %@", [self encodedUserInfoFor:error]);
                    [self.authorizationManager saveAuthorization:authorization toKeychain:keychainKey];
                }
                validationCompleted();
            }];
        } else {
            GCWCalendarAuthorization* authorization = [self.authorizationManager getAuthorizationFromKeychain:keychainKey];
            [self.authorizationManager removeAuthorization:authorization fromKeychain:keychainKey];
            validationCompleted();
        }
    }];
}

- (void)saveState {
    NSMutableArray *userIDs = [NSMutableArray array];
    NSArray *authorizations = [self.authorizationManager getAuthorizations];
    [authorizations enumerateObjectsUsingBlock:^(GCWCalendarAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        __block BOOL found = NO;
        [userIDs enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *userID = (NSString *)obj;
            if ([userID isEqualToString:authorization.userID]) {
                found = YES;
                *stop = YES;
            }
        }];
        if (!found) {
            [userIDs addObject: authorization.userID];
        }
    }];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *filePath = [[paths objectAtIndex:0] stringByAppendingPathComponent:kCalendarEventsKey];
    NSArray *archive = [self.calendarEvents archiveCalendarEvents];
    [archive writeToFile:filePath atomically:YES];

    [self.userDefaults setObject:userIDs forKey:kUserIDs];
    [self.userDefaults setObject:self.calendarSyncTokens forKey:kCalendarSyncTokensKey];
    [self.userDefaults setObject:[self.calendarEntries archiveCalendarEntries] forKey:kCalendarEntriesKey];
    [self.userDefaults setObject:self.notificationPeriod forKey:kCalendarEventsNotificationPeriodKey];
    [self.userDefaults synchronize];

    NSLog(@"SAVED: %lu users, %lu calendars and %lu events.", (unsigned long)userIDs.count, (unsigned long)self.calendarEntries.count, (unsigned long)archive.count);
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
                                                        scopes:self.authorizationScopes
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
        // performs authentication request
        self.currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.presentingViewController
                                                       callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
            if (authState) {
                GTMAppAuthFetcherAuthorization *fetcherAuthorization = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
                fetcherAuthorization.authState.stateChangeDelegate = self;

                GCWCalendarAuthorization *authorization = [[GCWCalendarAuthorization alloc] initWithFetcherAuthorization:fetcherAuthorization];
                [self.authorizationManager saveAuthorization:authorization
                                                  toKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];
                
                [self loadUserInfoForAuthorization:authorization success:^(NSDictionary *userInfo) {
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

- (void)doLogoutOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    NSURL *issuer = [NSURL URLWithString:kIssuerURI];
    NSURL *redirectURI = [NSURL URLWithString:@"https://google.com"];
    NSURL *endSessionURL = [issuer URLByAppendingPathComponent:@"connect/endsession"];

    self.userAccounts = [NSMutableDictionary dictionary];
    NSArray *userIDs = [self.userDefaults arrayForKey:kUserIDs];

    if (!userIDs || userIDs.count == 0) {
        failure([NSError errorWithDomain:@"CalendarWrapperErrorDomain"
                                    code:-10001
                                userInfo:@{NSLocalizedDescriptionKey:@"No valid authorization"}]);
        return;
    }
    // discovers endpoints
    [OIDAuthorizationService discoverServiceConfigurationForIssuer:issuer completion:^(OIDServiceConfiguration *configuration, NSError *error) {
        if (!configuration) {
            NSLog(@"CalendarWrapper: Error retrieving discovery document: %@", [self encodedUserInfoFor:error]);
            dispatch_async(dispatch_get_main_queue(), ^{
                failure(error);
            });
            return;
        }
        OIDServiceConfiguration *endpointConf = [[OIDServiceConfiguration alloc] initWithAuthorizationEndpoint:configuration.authorizationEndpoint
                                                                                                 tokenEndpoint:configuration.tokenEndpoint
                                                                                                        issuer:issuer
                                                                                          registrationEndpoint:configuration.registrationEndpoint
                                                                                            endSessionEndpoint:endSessionURL];
        if (!endpointConf) {
            dispatch_async(dispatch_get_main_queue(), ^{
                failure([NSError errorWithDomain:@"CalendarWrapperErrorDomain"
                                            code:-10007
                                        userInfo:@{NSLocalizedDescriptionKey:@"No valid end_session_endpoint"}]);
            });
            return;
        }
        [userIDs enumerateObjectsUsingBlock:^(id  _Nonnull userID, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *keychainKey = [GCWCalendarAuthorizationManager getKeychainKeyForUser:userID];

            GCWCalendarAuthorization* authorization = [self.authorizationManager getAuthorizationFromKeychain:keychainKey];
            authorization.fetcherAuthorization.authState.stateChangeDelegate = self;
            NSString *lastToken = authorization.fetcherAuthorization.authState.lastTokenResponse.idToken;

            [self.authorizationManager removeAuthorization:authorization
                                              fromKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];

            OIDEndSessionRequest *request = [[OIDEndSessionRequest alloc] initWithConfiguration:endpointConf
                                                                                    idTokenHint:lastToken
                                                                          postLogoutRedirectURL:redirectURI
                                                                           additionalParameters:nil];

            OIDExternalUserAgentIOS *agent = [[OIDExternalUserAgentIOS alloc] initWithPresentingViewController:self.presentingViewController];

            self.currentAuthorizationFlow = [OIDAuthorizationService presentEndSessionRequest:request
                                                                            externalUserAgent:agent
                                                                                     callback:^(OIDEndSessionResponse *endSessionResponse,
                                                                                                NSError *error) {
                self.userAccounts = [NSMutableDictionary dictionary];
                [self.userDefaults setValue:@[] forKey:kUserIDs];

                if (error) {
                    failure(error);
                } else {
                    success();
                }
            }];
        }];
    }];
}

- (void)doAuthorizationOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
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
                                                        scopes:self.authorizationScopes
                                                   redirectURL:redirectURI
                                                  responseType:OIDResponseTypeCode
                                          additionalParameters:nil];
        // performs authentication request
        self.currentAuthorizationFlow =
        [OIDAuthState authStateByPresentingAuthorizationRequest:request
                                       presentingViewController:self.presentingViewController
                                                       callback:^(OIDAuthState *_Nullable authState, NSError *_Nullable error) {
            if (authState) {
                NSLog(@"%@", authState.scope);
                GTMAppAuthFetcherAuthorization *fetcherAuthorization = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:authState];
                fetcherAuthorization.authState.stateChangeDelegate = self;

                GCWCalendarAuthorization *authorization = [[GCWCalendarAuthorization alloc] initWithFetcherAuthorization:fetcherAuthorization];
                [self.authorizationManager saveAuthorization:authorization
                                                  toKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];
                [authState setNeedsTokenRefresh];
                [authState performActionWithFreshTokens:^(NSString * _Nullable accessToken, NSString * _Nullable idToken, NSError * _Nullable error) {
                    if (error) {
                        failure(error);
                    } else {
                        GCWCalendarAuthorization *freshAuthorization = [self.authorizationManager getAuthorizationFromKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];

                        [self loadUserInfoForAuthorization:freshAuthorization success:^(NSDictionary *userInfo) {
                            NSString *userName = [userInfo valueForKey:@"name"];
                            if (userName && ![self.userAccounts valueForKey:freshAuthorization.userID]) {
                                GCWUserAccount *account = [[GCWUserAccount alloc] initWithUserInfo:userInfo];
                                [self.userAccounts setValue:account forKey:freshAuthorization.userID];
                            }
                            [self saveState];

                            dispatch_async(dispatch_get_main_queue(), success);
                        } failure:^(NSError *error) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                failure(error);
                            });
                        }];
                    }
                }];
            } else {
                failure(error);
            }
        }];
    }];
}

- (GCWCalendarAuthorization *)getAuthorizationForCalendar:(NSString *)calendarId {
    __block GCWCalendarAuthorization *calendarAuthorization = nil;
    NSString *userId = self.calendarUsers[calendarId];
    NSArray *authorizations = [self.authorizationManager getAuthorizations];
    [authorizations enumerateObjectsUsingBlock:^(GCWCalendarAuthorization * _Nonnull authorization, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([authorization.userID isEqualToString:userId]) {
            calendarAuthorization = authorization;
            *stop = YES;
        }
    }];
    return calendarAuthorization;
}

- (void)loadUserInfoForAuthorization:(GCWCalendarAuthorization *)authorization
                                      success:(void (^)(NSDictionary *))success
                                      failure:(void (^)(NSError *))failure {
    GTMSessionFetcherService *fetcherService = [[GTMSessionFetcherService alloc] init];
    fetcherService.authorizer = authorization.fetcherAuthorization;
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

+ (GCWCalendarEvent *)createTaskWithCalendar:(NSString *)calendarId
                                  taskListId:(NSString *)taskListId
                                       title:(NSString *)title
                                     details:(NSString *)details
                                         due:(NSDate *)date
                          notificationPeriod:(NSNumber *)notificationPeriod {

    GCWCalendarEvent *event = [GCWCalendar createEventWithTitle:title
                                                       location:nil
                                        attendeesEmailAddresses:nil
                                                    description:details
                                                           date:date
                                                       duration:kAllDayDuration
                                             notificationPeriod:notificationPeriod
                                                      important:NO];
    event.calendarId = calendarId;
    event.taskListId = taskListId;
    event.type = GCWCalendarEventTypeTask;

    return event;
}

+ (GCWCalendarEvent *)createTaskWithId:(NSString *)identifier
                              calendar:(NSString *)calendarId
                                 title:(NSString *)title
                              description:(NSString *)description
                                     date:(NSDate *)date
                       notificationPeriod:(NSNumber *)notificationPeriod {
    
    GCWCalendarEvent *event = [GCWCalendar createEventWithTitle:title
                                                       location:nil
                                        attendeesEmailAddresses:nil
                                                    description:description
                                                           date:date
                                                       duration:kAllDayDuration
                                             notificationPeriod:notificationPeriod
                                                      important:NO];
    event.identifier = identifier;
    event.calendarId = calendarId;
    event.type = GCWCalendarEventTypeTask;

    return event;
}

+ (GCWCalendarEvent *)createEventWithTitle:(NSString *)title
                                  location:(NSString *)location
                   attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                               description:(NSString *)description
                                      date:(NSDate *)date
                                  duration:(NSInteger)duration
                        notificationPeriod:(NSNumber *)notificationPeriod
                                 important:(BOOL)important {
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
    reminder.minutes = notificationPeriod;
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

    GTLRCalendar_Event_ExtendedProperties *extendedProperties = [[GTLRCalendar_Event_ExtendedProperties alloc] init];
    GTLRCalendar_Event_ExtendedProperties_Private *privateProperty = [[GTLRCalendar_Event_ExtendedProperties_Private alloc] init];
    [privateProperty setAdditionalProperty:[NSString stringWithFormat:@"%d", important] forName:@"GCWCalendarEventImportant"];
    [extendedProperties setPrivateProperty:privateProperty];
    [newEvent setExtendedProperties:extendedProperties];

    return [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:newEvent];
}

+ (GCWCalendarEvent *)cloneEvent:(GCWCalendarEvent *)event {
    GCWCalendarEvent *clone = [[GCWCalendarEvent alloc] init];
    clone.calendarId = [event.calendarId copy];
    clone.start = [event.start copy];
    clone.end = [event.end copy];
    clone.summary = [event.summary copy];
    clone.location = [event.location copy];
    clone.descriptionProperty = [event.descriptionProperty copy];
    clone.recurrence = [event.recurrence copy];
    clone.attendees = [event.attendees copy];
    clone.reminders = [event.reminders copy];
    clone.isImportant = event.isImportant;
    clone.notificationPeriod = event.notificationPeriod;

    return clone;
}

- (void)loadCalendarListsForRole:(NSString *)accessRole
                         success:(void (^)(NSDictionary *))success
                         failure:(void (^)(NSError *))failure {
    NSMutableDictionary *calendars = [NSMutableDictionary dictionary];
    self.calendarUsers = [NSMutableDictionary dictionary];
    NSArray *authorizations = [self.authorizationManager getAuthorizations];

    __block NSUInteger authorizationIndex = 0;
    for (GCWCalendarAuthorization *authorization in authorizations) {
        [self loadCalendarListForAuthorization:authorization accessRole:accessRole success:^(NSDictionary *accountCalendars) {
            [calendars addEntriesFromDictionary:accountCalendars];
            if (authorizationIndex == authorizations.count-1) {
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

- (void)loadCalendarListForAuthorization:(GCWCalendarAuthorization *)authorization
                              accessRole:(NSString *)accessRole
                                 success:(void (^)(NSDictionary *))success
                                 failure:(void (^)(NSError *))failure {
    self.calendarService.authorizer = authorization.fetcherAuthorization;
    
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
                if (cachedCalendar) {
                    // Keep attribute value from cache
                    calendar.hideEvents = cachedCalendar.hideEvents;
                } else {
                    // By default show events only for owned calendars
                    calendar.hideEvents = ![calendar.accessRole isEqualToString:@"owner"];
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

- (void)loadEventForCalendar:(NSString *)calendarId
                     eventId:(NSString *)eventId
                     success:(void (^)(GCWCalendarEvent *))success
                     failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization.fetcherAuthorization;

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

- (void)loadEventsListFrom:(NSDate *)startDate
                        to:(NSDate *)endDate
                    filter:(NSString *)filter
                   success:(void (^)(NSDictionary *, NSArray *, NSUInteger, NSArray *))success
                   failure:(void (^)(NSError *))failure {

    __block NSUInteger filteredEventsCount = 0;
    NSMutableDictionary *removedEvents = [NSMutableDictionary dictionary];
    NSMutableDictionary *loadedEvents = [NSMutableDictionary dictionary];
    NSMutableArray *errors = [NSMutableArray array];
    __block NSUInteger calendarIndex = 0;
    for (GCWCalendarEntry *calendar in self.calendarEntries.allValues) {
        if (calendar.hideEvents) {
            if (calendarIndex == self.calendarEntries.count-1) {
                success([loadedEvents copy], removedEvents.allValues, filteredEventsCount, [errors copy]);
            } else {
                calendarIndex++;
            }
            continue;
        }
        GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendar.identifier];
        if (!authorization) {
            failure([NSError createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendar.identifier]]);
            return;
        }
        self.calendarService.authorizer = authorization.fetcherAuthorization;
        
        GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendar.identifier];
        query.maxResults = 2500;
        query.singleEvents = true;
        query.timeMin = [GTLRDateTime dateTimeWithDate:startDate];
        query.timeMax = [GTLRDateTime dateTimeWithDate:endDate];
        query.orderBy = kGTLRCalendarOrderByStartTime;
        [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                [errors addObject:callbackError];
            } else {
                GTLRCalendar_Events *list = object;
                [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                    event.calendarId = calendar.identifier;
                    if (filter.length && [event.JSONString.lowercaseString containsString:filter.lowercaseString]) {
                        filteredEventsCount++;
                    }
                    if ([event.status isEqualToString:@"cancelled"]) {
                        [self.calendarEvents removeObjectForKey:event.identifier];
                        removedEvents[event.identifier] = event;
                    } else if (([event.startDate isLaterThanOrEqualTo:startDate] &&
                                [event.endDate isEarlierThanOrEqualTo:endDate]) ||
                               labs([event.startDate numberOfDaysUntil:event.endDate]) == 1) {
                        event.color = [UIColor colorWithHex:calendar.backgroundColor];

                        id item = self.calendarEvents[event.identifier];

                        if ([item isKindOfClass:NSDictionary.class]) {
                            NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)item];
                            GCWCalendarEvent *cachedEvent = items[calendar.identifier];

                            // Keep attributes from cached object
                            if (cachedEvent) {
                                event.isImportant = cachedEvent.isImportant;
                            }
                            items[calendar.identifier] = event;

                            self.calendarEvents[event.identifier] = items.copy;
                        } else {
                            GCWCalendarEvent *cachedEvent = self.calendarEvents[event.identifier];

                            if (cachedEvent == nil || [cachedEvent.calendarId isEqualToString:event.calendarId]) {
                                // Keep attributes from cached object
                                if (cachedEvent) {
                                    event.isImportant = cachedEvent.isImportant;
                                }
                                self.calendarEvents[event.identifier] = event;
                            } else {
                                NSMutableDictionary *items = [NSMutableDictionary dictionary];
                                items[event.calendarId] = event;
                                items[cachedEvent.calendarId] = cachedEvent;

                                self.calendarEvents[event.identifier] = items.copy;
                            }
                        }
                        loadedEvents[event.identifier] = event;
                    }
                }];
            }
            if (calendarIndex == self.calendarEntries.count-1) {
                success([loadedEvents copy], removedEvents.allValues, filteredEventsCount, [errors copy]);
            }
            calendarIndex++;
        }];
    }
}

- (void)loadRecurringEventInstancesFor:(NSString *)recurringEventId
                              calendar:(NSString *)calendarId
                                  from:(NSDate *)startDate
                                    to:(NSDate *)endDate
                               success:(void (^)(NSArray *))success
                               failure:(void (^)(NSError *))failure {

    __block NSMutableArray *eventInstances = [NSMutableArray array];

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization.fetcherAuthorization;

    GCWCalendarEntry *calendar = self.calendarEntries[calendarId];

    GTLRCalendarQuery_EventsInstances *query = [GTLRCalendarQuery_EventsInstances queryWithCalendarId:calendarId eventId:recurringEventId];
    query.maxResults = 2500;
    query.showDeleted = NO;
    if (startDate != nil) {
        query.timeMin = [GTLRDateTime dateTimeWithDate:startDate];
    }
    if (endDate != nil) {
        query.timeMax = [GTLRDateTime dateTimeWithDate:endDate];
    }
    [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
            return;
        } else {
            GTLRCalendar_Events *list = object;
            [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                event.calendarId = calendarId;
                event.color = [UIColor colorWithHex:calendar.backgroundColor];

                [eventInstances addObject:event];
            }];
            success([eventInstances copy]);
        }
    }];
}

- (GCWLoadEventsListRequest *)createEventsListRequest {
    return [[GCWLoadEventsListRequest alloc] initWithCalendarEntries:self.calendarEntries
                                                authorizationManager:self.authorizationManager
                                                       calendarUsers:self.calendarUsers];
}

- (NSArray *)getFetchedEventsBefore:(NSDate *)startDate andAfter:(NSDate *)endDate {
    NSMutableArray *events = [NSMutableArray array];
    [self.calendarEvents enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)obj];
            [items enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                if (([event.startDate isEarlierThan:startDate] ||
                     [event.endDate isLaterThan:endDate]) &&
                    labs([event.startDate numberOfDaysUntil:event.endDate]) <= 1) {
                    [events addObject:event.identifier];
                }
            }];
        } else {
            GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
            if (([event.startDate isEarlierThan:startDate] ||
                 [event.endDate isLaterThan:endDate]) &&
                labs([event.startDate numberOfDaysUntil:event.endDate]) <= 1) {
                [events addObject:event.identifier];
            }
        }
    }];
    return [events copy];
}

- (void)syncEventsFrom:(NSDate *)startDate
                    to:(NSDate *)endDate
               success:(void (^)(NSDictionary *, NSArray *, NSArray *, NSArray *))success
               failure:(void (^)(NSError *))failure
              progress:(void (^)(CGFloat))progress {

    NSMutableDictionary *removedEvents = [NSMutableDictionary dictionary];
    NSMutableDictionary *syncedEvents = [NSMutableDictionary dictionary];
    NSMutableArray *expiredTokens = [NSMutableArray array];
    NSMutableArray *errors = [NSMutableArray array];

    __block NSUInteger calendarIndex = 0;
    __block CGFloat percent = 0.0f;
    __block CGFloat calendarPercent = 0.0f;
    for (GCWCalendarEntry *calendar in self.calendarEntries.allValues) {
        GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendar.identifier];
        if (!authorization) {
            failure([NSError createErrorWithCode:-10002
                                     description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendar.identifier]]);
            return;
        }
        self.calendarService.authorizer = authorization.fetcherAuthorization;

        GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendar.identifier];
        query.maxResults = 2500;
        query.singleEvents = true;
        query.syncToken = self.calendarSyncTokens[calendar.identifier];
        [self.calendarSyncTokens removeObjectForKey:calendar.identifier];

        calendarPercent = 0;
        [self.calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            dispatch_async(self.eventsQueue, ^{
                if (callbackError) {
                    if (callbackError.code == 410) {
                        // In case sync token has expired mark it for removal.
                        [expiredTokens addObject:calendar.identifier];
                    } else {
                        [errors addObject:callbackError];
                    }
                } else {
                    GTLRCalendar_Events *list = object;
                    [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                        event.calendarId = calendar.identifier;

                        CGFloat portion = floor(100.0f * (CGFloat)idx / (CGFloat)list.items.count / (CGFloat)self.calendarEntries.count);
                        if (calendarPercent != portion) {
                            calendarPercent = portion;
                            progress(percent + calendarPercent);
                        }
                        if ([event.status isEqualToString:@"cancelled"]) {
                            id item = self.calendarEvents[event.identifier];
                            if ([item isKindOfClass:NSDictionary.class]) {
                                NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)item];
                                [items removeObjectForKey:event.calendarId];
                                self.calendarEvents[event.identifier] = items.copy;
                            } else {
                                [self.calendarEvents removeObjectForKey:event.identifier];
                            }
                            removedEvents[event.identifier] = event;
                        } else if (([event.startDate isLaterThanOrEqualTo:startDate] &&
                                    [event.endDate isEarlierThanOrEqualTo:endDate]) ||
                                   labs([event.startDate numberOfDaysUntil:event.endDate]) > 1) {
                            event.color = [UIColor colorWithHex:calendar.backgroundColor];

                            id item = self.calendarEvents[event.identifier];

                            if ([item isKindOfClass:NSDictionary.class]) {
                                NSMutableDictionary *items = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)item];

                                items[calendar.identifier] = event;

                                self.calendarEvents[event.identifier] = items.copy;
                            } else {
                                GCWCalendarEvent *cachedEvent = self.calendarEvents[event.identifier];

                                if (cachedEvent == nil || [cachedEvent.calendarId isEqualToString:event.calendarId]) {
                                    self.calendarEvents[event.identifier] = event;
                                } else {
                                    NSMutableDictionary *items = [NSMutableDictionary dictionary];
                                    items[event.calendarId] = event;
                                    items[cachedEvent.calendarId] = cachedEvent;

                                    self.calendarEvents[event.identifier] = items.copy;
                                }
                            }
                            syncedEvents[event.identifier] = event;
                        }
                    }];
                    self.calendarSyncTokens[calendar.identifier] = [list nextSyncToken];
                }
                if (calendarIndex == self.calendarEntries.count-1) {
                    success([syncedEvents copy], removedEvents.allValues, [expiredTokens copy], [errors copy]);
                }
                calendarIndex++;
                percent = floor(100.0f * (CGFloat)calendarIndex / (CGFloat)self.calendarEntries.count);
                progress(percent);
            });
        }];
    }
}

- (void)addEvent:(GCWCalendarEvent *)event
      toCalendar:(NSString *)calendarId
         success:(void (^)(GCWCalendarEvent *))success
         failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization.fetcherAuthorization;

    GTLRCalendarQuery_EventsInsert *query = [GTLRCalendarQuery_EventsInsert queryWithObject:event calendarId:calendarId];
    [self.calendarService executeQuery:query
                     completionHandler:^(GTLRServiceTicket *callbackTicket,
                                         GTLRCalendar_Event *obj,
                                         NSError *callbackError) {
        GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
        event.calendarId = calendarId;
        if (callbackError == nil) {
            success(event);
        } else {
            failure(callbackError);
        }
    }];
}

- (void)deleteEvent:(NSString *)eventId
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization.fetcherAuthorization;

    GTLRCalendarQuery_EventsDelete *query = [GTLRCalendarQuery_EventsDelete
                                             queryWithCalendarId:calendarId
                                             eventId:eventId];
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

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.calendarService.authorizer = authorization.fetcherAuthorization;

    GTLRCalendarQuery_EventsUpdate *query = [GTLRCalendarQuery_EventsUpdate queryWithObject:event calendarId:calendarId eventId:event.identifier];
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

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *)events
               success:(void (^)(NSArray<GCWCalendarEvent *> *))success
               failure:(void (^)(NSError *))failure {

    NSMutableArray *clonedEvents = [NSMutableArray array];
    NSMutableDictionary *calendarEvents = [NSMutableDictionary dictionary];

    for (GCWCalendarEvent *event in events) {
        NSString *calendarId = event.calendarId;

        if (calendarEvents[calendarId] == nil) {
            calendarEvents[calendarId] = [NSMutableArray array];
        }
        NSMutableArray *events = calendarEvents[calendarId];
        [events addObject:event];
    }
    __block NSUInteger calendarIndex = 0;
    for (NSString *calendarId in calendarEvents.allKeys) {
        GCWCalendarEntry *calendar = self.calendarEntries[calendarId];
        NSArray *groupedEvents = calendarEvents[calendarId];

        GTLRBatchQuery *batchQuery = [[GTLRBatchQuery alloc] init];
        for (GCWCalendarEvent *event in groupedEvents) {
            GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
            if (!authorization) {
                failure([NSError createErrorWithCode:-10002
                                         description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
                return;
            }
            self.calendarService.authorizer = authorization.fetcherAuthorization;

            GTLRCalendarQuery_EventsInsert *query = [GTLRCalendarQuery_EventsInsert queryWithObject:event calendarId:calendarId];
            [batchQuery addQuery:query];
        }
        [self.calendarService executeQuery:batchQuery
                         completionHandler:^(GTLRServiceTicket *callbackTicket,
                                             id nilObject,
                                             NSError *callbackError) {
                             if (callbackError == nil) {
                                 GTLRBatchResult *result = nilObject;
                                 [result.successes.allValues enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                     GCWCalendarEvent *clonedEvent = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];

                                     clonedEvent.calendarId = calendar.identifier;
                                     clonedEvent.color = [UIColor colorWithHex:calendar.backgroundColor];
                                     [clonedEvents addObject:clonedEvent];
                                 }];
                                 if (calendarIndex == calendarEvents.count-1) {
                                     success(clonedEvents);
                                 }
                                 calendarIndex++;
                             } else {
                                 failure(callbackError);
                             }
        }];
    }
}

- (void)batchUpdateEvents:(NSArray <GCWCalendarEvent *> *)events
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure {

    NSMutableDictionary *calendarEvents = [NSMutableDictionary dictionary];
    for (GCWCalendarEvent *event in events) {
        NSString *calendarId = event.calendarId;

        if (calendarEvents[calendarId] == nil) {
            calendarEvents[calendarId] = [NSMutableArray array];
        }
        NSMutableArray *events = calendarEvents[calendarId];
        [events addObject:event];
    }
    for (NSString *calendarId in calendarEvents.allKeys) {
        NSArray *groupedEvents = calendarEvents[calendarId];

        GTLRBatchQuery *batchQuery = [[GTLRBatchQuery alloc] init];
        for (GCWCalendarEvent *event in groupedEvents) {
            GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
            if (!authorization) {
                failure([NSError createErrorWithCode:-10002
                                         description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
                return;
            }
            self.calendarService.authorizer = authorization.fetcherAuthorization;

            GTLRCalendarQuery_EventsUpdate *query = [GTLRCalendarQuery_EventsUpdate queryWithObject:event calendarId:calendarId eventId:event.identifier];
            [batchQuery addQuery:query];
        }
        [self.calendarService executeQuery:batchQuery
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
}

- (void)batchDeleteEvents:(NSArray <NSString *> *)eventIds
            fromCalendars:(NSArray <NSString *> *)calendarIds
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure {
   NSAssert(eventIds.count == calendarIds.count, @"There must be calendarId for each eventId");

    NSMutableDictionary *calendarEvents = [NSMutableDictionary dictionary];
    for (int index=0; index < eventIds.count; index++) {
        NSString *calendarId = calendarIds[index];

        if (calendarEvents[calendarId] == nil) {
            calendarEvents[calendarId] = [NSMutableArray array];
        }
        NSString *eventId = eventIds[index];
        NSMutableArray *events = calendarEvents[calendarId];
        [events addObject:eventId];
    }
    for (NSString *calendarId in calendarEvents.allKeys) {
        NSArray *events = calendarEvents[calendarId];

        GTLRBatchQuery *batchQuery = [[GTLRBatchQuery alloc] init];
        for (NSString *eventId in events) {
            GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
            if (!authorization) {
                failure([NSError createErrorWithCode:-10002
                                         description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
                return;
            }
            self.calendarService.authorizer = authorization.fetcherAuthorization;

            GTLRCalendarQuery_EventsDelete *query = [GTLRCalendarQuery_EventsDelete
                                                     queryWithCalendarId:calendarId
                                                     eventId:eventId];

            [batchQuery addQuery:query];
        }
        [self.calendarService executeQuery:batchQuery
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
}

- (void)getContactsFor:(NSString *)calendarId
               success:(void (^)(NSArray <GCWPerson *> *))success
               failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.peopleService.authorizer = authorization.fetcherAuthorization;

    GTLRPeopleServiceQuery_PeopleConnectionsList *query = [GTLRPeopleServiceQuery_PeopleConnectionsList queryWithResourceName:@"people/me"];
    query.pageSize = 1000;
    query.personFields = @"names,emailAddresses,photos";
    [self.peopleService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            NSMutableArray *persons = [NSMutableArray array];
            success([persons copy]);
        }
    }];
}

- (void)getPeopleFor:(NSString *)calendarId
             success:(void (^)(NSArray <GCWPerson *> *))success
             failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendarId]]);
        return;
    }
    self.peopleService.authorizer = authorization.fetcherAuthorization;

    GTLRPeopleServiceQuery_PeopleListDirectoryPeople *query = [GTLRPeopleServiceQuery_PeopleListDirectoryPeople query];
    query.pageSize = 1000;
    query.sources = @[kGTLRPeopleServiceSourcesDirectorySourceTypeDomainContact, kGTLRPeopleServiceSourcesDirectorySourceTypeDomainProfile];
    query.readMask = @"genders,names,nicknames,emailAddresses,occupations,organizations,phoneNumbers,photos";
    [self.peopleService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            if (callbackError.code == 403) {
                GTLRErrorObject *error = callbackError.userInfo[kGTLRStructuredErrorKey];
                if ([error.status isEqualToString:@"PERMISSION_DENIED"]) {
                    failure([NSError createErrorWithCode:-10009
                                             description:[NSString stringWithFormat: @"People list permission denied for %@", calendarId]]);
                    return;
                }
            }
            failure(callbackError);
        } else {
            NSMutableArray *persons = [NSMutableArray array];
            GTLRPeopleService_ListDirectoryPeopleResponse *response = (GTLRPeopleService_ListDirectoryPeopleResponse *)object;
            for (GTLRPeopleService_Person *person in response.people) {
                GCWPerson *gcwPerson = [[GCWPerson alloc] initWithPerson:person];
                [persons addObject:gcwPerson];
            }
            success([persons copy]);
        }
    }];
}

- (void)loadTaskListsOnSuccess:(void (^)(NSDictionary *))success
                       failure:(void (^)(NSError *))failure {

    __block NSMutableDictionary *taskListsDictionary = [NSMutableDictionary dictionary];

    GCWCalendarEntry *calendar = self.calendarEntries.allValues.firstObject;
    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendar.identifier];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendar.identifier]]);
        return;
    }
    self.tasksService.authorizer = authorization.fetcherAuthorization;

    GTLRTasksQuery_TasklistsList *query = [GTLRTasksQuery_TasklistsList query];
    query.maxResults = 100;
    [self.tasksService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            if (callbackError.code == 403) {
                GTLRErrorObject *error = callbackError.userInfo[kGTLRStructuredErrorKey];
                if ([error.status isEqualToString:@"PERMISSION_DENIED"]) {
                    failure([NSError createErrorWithCode:-10008
                                             description:[NSString stringWithFormat: @"Task lists permission denied for %@", calendar.identifier]]);
                    return;
                }
            }
            failure(callbackError);
        } else {
            GTLRTasks_TaskLists *taskLists = (GTLRTasks_TaskLists *)object;
            for (GTLRTasks_TaskList *taskList in taskLists.items) {
                GCWTaskList *gcwTaskList = [[GCWTaskList alloc] initWithTaskList:taskList calendar:calendar.identifier];
                [taskListsDictionary setValue:gcwTaskList forKey:taskList.identifier];
            }
            self.taskLists = [taskListsDictionary copy];
            success([taskListsDictionary copy]);
        }
    }];
}

- (void)syncTasksOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {

    __block NSUInteger listIndex = 0;
    NSMutableArray *errors = [NSMutableArray array];

    for (GCWTaskList *taskList in self.taskLists.allValues) {
        GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:taskList.calendarId];
        if (!authorization) {
            failure([NSError createErrorWithCode:-10002
                                     description:[NSString stringWithFormat:@"Missing authorization for calendar %@", taskList.calendarId]]);
            return;
        }
        GCWCalendarEntry *calendar = self.calendarEntries[taskList.calendarId];

        self.tasksService.authorizer = authorization.fetcherAuthorization;
        self.tasksService.shouldFetchNextPages = YES;

        GTLRTasksQuery_TasksList *tasksQuery = [GTLRTasksQuery_TasksList queryWithTasklist:taskList.identifier];
        tasksQuery.showCompleted = YES;
        tasksQuery.showHidden = YES;
        tasksQuery.showDeleted = YES;
        [self.tasksService executeQuery:tasksQuery completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                [errors addObject:callbackError];
            } else {
                GTLRTasks_Tasks *tasks = (GTLRTasks_Tasks *)object;
                for (GTLRTasks_Task *task in tasks.items) {
                    if (task.due) {
                        if (task.deleted) {
                            [self.calendarEvents removeObjectForKey:task.identifier];
                        } else {
                            NSDate *dueDate = [[NSDateFormatter rfc3339X5Formatter] dateFromString:task.due];
                            GCWCalendarEvent *event = [GCWCalendar createTaskWithId:task.identifier
                                                                           calendar:calendar.identifier
                                                                              title:task.title
                                                                           description:task.notes
                                                                                  date:dueDate
                                                                    notificationPeriod:self.notificationPeriod];
                            event.color = [UIColor colorWithHex:calendar.backgroundColor];
                            event.taskListId = taskList.identifier;
                            event.taskStatus = [task.status isEqualToString:@"completed"] ? GCWCalendarTaskStatusCompleted : GCWCalendarTaskStatusNeedsAction;
                            self.calendarEvents[event.identifier] = event;
                        }
                    }
                }
            }
            if (listIndex == self.taskLists.count-1) {
                if (errors.count > 0) {
                    failure(errors.firstObject);
                } else {
                    success();
                }
            }
            listIndex++;
        }];
    }
}

- (void)getTaskForEvent:(GCWCalendarEvent *)event
                success:(void (^)(GCWTaskList *, GTLRTasks_Task *))success
                failure:(void (^)(NSError *))failure {

    __block NSUInteger listIndex = 0;
    __block NSMutableArray *errors = [NSMutableArray array];
    __block GCWTaskList *eventTaskList;
    __block GTLRTasks_Task *eventTask;

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:event.calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat:@"Missing authorization for calendar %@", event.calendarId]]);
        return;
    }
    self.tasksService.authorizer = authorization.fetcherAuthorization;
    self.tasksService.shouldFetchNextPages = YES;

    for (GCWTaskList *taskList in self.taskLists.allValues) {
        GTLRTasksQuery_TasksList *tasksQuery = [GTLRTasksQuery_TasksList queryWithTasklist:taskList.identifier];
        tasksQuery.showCompleted = YES;
        tasksQuery.showHidden = YES;
        [self.tasksService executeQuery:tasksQuery completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                [errors addObject:callbackError];
            } else {
                GTLRTasks_Tasks *tasks = (GTLRTasks_Tasks *)object;
                for (GTLRTasks_Task *task in tasks.items) {
                    if ([task.identifier isEqualToString:event.identifier]) {
                        eventTaskList = taskList;
                        eventTask = task;
                        success(eventTaskList, eventTask);
                        return;
                    }
                }
            }
            if (listIndex == self.taskLists.count-1) {
                if (errors.count > 0) {
                    failure(errors.firstObject);
                } else {
                    failure([NSError createErrorWithCode:-10006
                                             description:[NSString stringWithFormat: @"Task not found for id %@", event.identifier]]);
                }
            }
            listIndex++;
        }];
    }
}

- (void)insertTaskWithEvent:(GCWCalendarEvent *)event
                    success:(void (^)(NSString *))success
                    failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:event.calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat:@"Missing authorization for calendar %@", event.calendarId]]);
        return;
    }
    GCWCalendarEntry *calendar = self.calendarEntries[event.calendarId];

    self.tasksService.authorizer = authorization.fetcherAuthorization;

    GTLRTasks_Task *task = [[GTLRTasks_Task alloc] init];
    task.title = event.summary;
    task.notes = event.descriptionProperty;
    task.due = [[NSDateFormatter rfc3339Formatter] stringFromDate:event.startDate];

    GTLRTasksQuery_TasksInsert *query = [GTLRTasksQuery_TasksInsert queryWithObject:task tasklist:event.taskListId];
    [self.tasksService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            GTLRTasks_Task *newTask = (GTLRTasks_Task *)object;
            NSDate *dueDate = [[NSDateFormatter rfc3339X5Formatter] dateFromString:task.due];
            GCWCalendarEvent *newEvent = [GCWCalendar createTaskWithId:newTask.identifier
                                                           calendar:calendar.identifier
                                                              title:newTask.title
                                                           description:newTask.notes
                                                                  date:dueDate
                                                    notificationPeriod:self.notificationPeriod];
            newEvent.color = [UIColor colorWithHex:calendar.backgroundColor];
            newEvent.taskListId = event.taskListId;
            newEvent.taskStatus = [newTask.status isEqualToString:@"completed"] ? GCWCalendarTaskStatusCompleted : GCWCalendarTaskStatusNeedsAction;
            self.calendarEvents[newTask.identifier] = newEvent;
            success(newTask.identifier);
        }
    }];
}

- (void)updateTaskWithEvent:(GCWCalendarEvent *)event
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *))failure {

    [self getTaskForEvent:event success:^(GCWTaskList *taskList, GTLRTasks_Task *task) {
        GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:event.calendarId];
        if (!authorization) {
            failure([NSError createErrorWithCode:-10002
                                     description:[NSString stringWithFormat:@"Missing authorization for calendar %@", event.calendarId]]);
            return;
        }
        self.tasksService.authorizer = authorization.fetcherAuthorization;

        task.title = event.summary;
        task.notes = event.descriptionProperty;
        task.due = [NSDateFormatter.rfc3339Formatter stringFromDate:event.startDate];
        switch (event.taskStatus) {
            case GCWCalendarTaskStatusNeedsAction:
                task.status = @"needsAction";
                break;
            case GCWCalendarTaskStatusCompleted:
                task.status = @"completed";
                break;
        }
        GTLRTasksQuery_TasksUpdate *query = [GTLRTasksQuery_TasksUpdate queryWithObject:task tasklist:taskList.identifier task:task.identifier];
        [self.tasksService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                failure(callbackError);
            } else {
                success();
            }
        }];
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)deleteTaskWithEvent:(GCWCalendarEvent *)event
                    success:(void (^)(void))success
                    failure:(void (^)(NSError *))failure {

    GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:event.calendarId];
    if (!authorization) {
        failure([NSError createErrorWithCode:-10002
                                 description:[NSString stringWithFormat:@"Missing authorization for calendar %@", event.calendarId]]);
        return;
    }
    self.tasksService.authorizer = authorization.fetcherAuthorization;

    GTLRTasksQuery_TasksDelete *query = [GTLRTasksQuery_TasksDelete queryWithTasklist:event.taskListId task:event.identifier];
    [self.tasksService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
        if (callbackError) {
            failure(callbackError);
        } else {
            success();
        }
    }];
}

#pragma mark  - OIDAuthStateChangeDelegate

- (void)didChangeState:(OIDAuthState *)state {
    GTMAppAuthFetcherAuthorization *fetcherAuthorization = [[GTMAppAuthFetcherAuthorization alloc] initWithAuthState:state];
    fetcherAuthorization.authState.stateChangeDelegate = self;

    GCWCalendarAuthorization *authorization = [[GCWCalendarAuthorization alloc] initWithFetcherAuthorization:fetcherAuthorization];
    [self.authorizationManager saveAuthorization:authorization
                                      toKeychain:[GCWCalendarAuthorizationManager getKeychainKeyForAuthorization:authorization]];
}

@end
