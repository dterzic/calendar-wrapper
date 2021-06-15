#import "GCWLoadEventsListRequest.h"

#import "GCWCalendar.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWCalendarAuthorizationManager.h"
#import "GCWCalendarAuthorization.h"

#import "UIColor+MNTColor.h"

@interface GCWLoadEventsListRequest ()

@property (nonatomic) NSMutableArray *calendarServiceTickets;
@property (nonatomic) NSMutableDictionary *events;
@property (nonatomic) BOOL cancelled;

@end

@implementation GCWLoadEventsListRequest

+ (NSError *)createErrorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil];
    return [NSError errorWithDomain:@"com.calendar-wrapper" code:code userInfo:userInfo];
}

- (instancetype)initWithCalendarEntries:(NSDictionary *)calendarEntries
                   authorizationManager:(id<CalendarAuthorizationProtocol>)authorizationManager
                          calendarUsers:(NSDictionary *)calendarUsers {
    self = [super init];
    if (self) {
        _authorizationManager = authorizationManager;
        _calendarUsers = calendarUsers;
        _calendarEntries = calendarEntries;

        _calendarServiceTickets = [NSMutableArray array];
        _events = [NSMutableDictionary dictionary];
    }
    return self;
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

- (void)startFrom:(NSDate *)startDate
          endDate:(NSDate *)endDate
           filter:(NSString *)filter
          success:(void (^)(NSArray *))success failure:(void (^)(NSError *))failure {
    
    GTLRCalendarService *calendarService = [[GTLRCalendarService alloc] init];
    calendarService.shouldFetchNextPages = YES;
    calendarService.retryEnabled = YES;

    __block NSUInteger calendarIndex = 0;
    for (GCWCalendarEntry *calendar in self.calendarEntries.allValues) {
        GCWCalendarAuthorization *authorization = [self getAuthorizationForCalendar:calendar.identifier];
        if (!authorization) {
            failure([GCWLoadEventsListRequest createErrorWithCode:-10002
                                                      description:[NSString stringWithFormat: @"Missing authorization for calendar %@", calendar.identifier]]);
            return;
        }
        calendarService.authorizer = authorization.fetcherAuthorization;
        calendarService.shouldFetchNextPages = YES;

        GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendar.identifier];
        query.timeMin = [GTLRDateTime dateTimeWithDate:startDate];
        query.timeMax = [GTLRDateTime dateTimeWithDate:endDate];
        query.singleEvents = YES;
        query.maxResults = 2500;
        query.orderBy = kGTLRCalendarOrderByStartTime;
        GTLRServiceTicket *ticket = [calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            if (callbackError) {
                failure(callbackError);
            } else {
                if (self.cancelled) {
                    return;
                }
                GTLRCalendar_Events *list = object;
                [list.items enumerateObjectsUsingBlock:^(GTLRCalendar_Event * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    GCWCalendarEvent *event = [[GCWCalendarEvent alloc] initWithGTLCalendarEvent:obj];
                    event.calendarId = calendar.identifier;
                    if (![event.status isEqualToString:@"cancelled"] &&
                        [event.JSONString.lowercaseString containsString:filter.lowercaseString]) {
                        event.color = [UIColor colorWithHex:calendar.backgroundColor];
                        self.events[event.identifier] = event;
                    }
                }];
                if (calendarIndex == self.calendarEntries.count-1) {
                    [self.calendarServiceTickets removeAllObjects];
                    success([self.events.allValues copy]);
                }
                calendarIndex++;
            }
        }];
        [self.calendarServiceTickets addObject:ticket];
    }
}

- (void)cancel {
    self.cancelled = YES;

    [self.calendarServiceTickets enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        GTLRServiceTicket *ticket = (GTLRServiceTicket *)obj;
        [ticket cancelTicket];
    }];
    [self.calendarServiceTickets removeAllObjects];
    [self.events removeAllObjects];

    self.cancelled = NO;
}

@end