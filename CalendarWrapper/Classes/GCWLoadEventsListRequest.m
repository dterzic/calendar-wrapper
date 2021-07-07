#import "GCWLoadEventsListRequest.h"

#import "GCWCalendar.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWCalendarAuthorizationManager.h"
#import "GCWCalendarAuthorization.h"

#import "NSError+GCWCalendar.h"
#import "UIColor+MNTColor.h"

@interface GCWLoadEventsListRequest ()

@property (nonatomic) NSMutableArray *calendarServiceTickets;
@property (nonatomic) NSMutableDictionary *events;
@property (nonatomic) BOOL cancelled;
@property (nonatomic) dispatch_queue_t eventsQueue;

@end

@implementation GCWLoadEventsListRequest

- (instancetype)initWithCalendarEntries:(NSDictionary *)calendarEntries
                   authorizationManager:(id<CalendarAuthorizationProtocol>)authorizationManager
                          calendarUsers:(NSDictionary *)calendarUsers {
    self = [super init];
    if (self) {
        self.eventsQueue = dispatch_queue_create("com.moment.gcwloadeventslistrequest.eventsqueue", DISPATCH_QUEUE_SERIAL);

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
          success:(void (^)(NSArray *))success
          failure:(void (^)(NSError *))failure
         progress:(void (^)(CGFloat))progress {

    GTLRCalendarService *calendarService = [[GTLRCalendarService alloc] init];
    calendarService.shouldFetchNextPages = YES;
    calendarService.retryEnabled = YES;

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
        calendarService.authorizer = authorization.fetcherAuthorization;
        calendarService.shouldFetchNextPages = YES;

        GTLRCalendarQuery_EventsList *query = [GTLRCalendarQuery_EventsList queryWithCalendarId:calendar.identifier];
        query.timeMin = [GTLRDateTime dateTimeWithDate:startDate];
        query.timeMax = [GTLRDateTime dateTimeWithDate:endDate];
        query.singleEvents = YES;
        query.maxResults = 2500;
        query.orderBy = kGTLRCalendarOrderByStartTime;

        calendarPercent = 0;
        GTLRServiceTicket *ticket = [calendarService executeQuery:query completionHandler:^(GTLRServiceTicket * _Nonnull callbackTicket, id  _Nullable object, NSError * _Nullable callbackError) {
            dispatch_async(self.eventsQueue, ^{
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

                        CGFloat portion = floor(100.0f * (CGFloat)idx / (CGFloat)list.items.count / (CGFloat)self.calendarEntries.count);
                        if (calendarPercent != portion) {
                            calendarPercent = portion;
                            progress(percent + calendarPercent);
                        }
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
                    percent = floor(100.0f * (CGFloat)calendarIndex / (CGFloat)self.calendarEntries.count);
                    progress(percent);
                }
            });
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
