#import "GCWCalendarService.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "NSDictionary+GCWCalendarEvent.h"
#import "NSArray+GCWEventsSorting.h"
#import "NSDictionary+GCWCalendar.h"
#import "NSDate+GCWDate.h"
#import "UIColor+MNTColor.h"

static NSString * const kClientID = @"350629588452-bcbi20qrl4tsvmtia4ps4q16d8i9sc4l.apps.googleusercontent.com";
static NSString * const kCalendarFilterKey = @"calendarWrapperCalendarFilterKey";
static NSUInteger daysInPast = -15;
static NSUInteger daysInFuture = 45;

@interface GCWCalendarService () <CalendarServiceProtocol>

@property (nonatomic) GCWCalendar *calendar;

@end

@implementation GCWCalendarService

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController delegate:(id<CalendarServiceDelegate>)delegate {
    self = [super init];
    if (self) {
        self.calendar = [[GCWCalendar alloc] initWithClientId:kClientID
                                            presentingViewController:presentingViewController];
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - CalendarServiceProtocol

- (NSString *)getCalendarOwner:(NSString *)calendarId {
    return [self.calendar getCalendarOwner:calendarId];
}

- (NSDictionary *)calendarEvents {
    return self.calendar.calendarEvents;
}

- (NSDictionary *)calendarEntries {
    return self.calendar.calendarEntries;
}

- (NSDictionary *)accountEntries {
    return self.calendar.accountEntries;
}

- (NSDictionary *)userAccounts {
    return self.calendar.userAccounts;
}

- (void)setCalendarListEntries:(NSDictionary *)calendarListEntries {
    self.calendar.calendarEntries = calendarListEntries;
}

- (void)setVisibility:(BOOL)visible forCalendar:(NSString *)calendarId {
    NSMutableDictionary *calendarEntries = [NSMutableDictionary dictionaryWithDictionary:self.calendarEntries];
    GCWCalendarEntry *entry = calendarEntries[calendarId];
    entry.hideEvents = visible;
    [calendarEntries setValue:entry forKey:calendarId];
    self.calendar.calendarEntries = calendarEntries;
}

- (BOOL)resumeAuthorizationFlowWithURL:(NSURL *)url {
    if ([self.calendar.currentAuthorizationFlow resumeExternalUserAgentFlowWithURL:url]) {
        self.calendar.currentAuthorizationFlow = nil;
        return YES;
    }
    return NO;
}

- (void)loadAuthorizationsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    [self.calendar loadAuthorizationsOnSuccess:^{
        success();
    } failure:^(NSError * error) {
        failure(error);
    }];
}

- (void)doLoginOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    [self.calendar doLoginOnSuccess:^{
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)loadCalendarListOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    [self.calendar loadCalendarListsForRole:kGTLRCalendarMinAccessRoleReader
                                           success:^(NSDictionary *calendars) {
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)syncEventsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure {
    NSDate *startDate = [NSDate dateFromNumberOfDaysSinceNow:daysInPast];
    NSDate *endDate = [NSDate dateFromNumberOfDaysSinceNow:daysInFuture];

    __weak GCWCalendarService *weakSelf = self;
    [self.calendar syncEventsFrom:startDate to:endDate success:^(NSDictionary *events) {
        for (GCWCalendarEvent *event in events.allValues) {
            if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidSyncEvent:)]) {
                [weakSelf.delegate calendarServiceDidSyncEvent:event];
            }
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)createEventForCalendar:(NSString *)calendarId
                     withTitle:(NSString *)title
                      location:(NSString *)location
       attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                   description:(NSString *)description
                          date:(NSDate *)date
                      duration:(NSInteger)duration
                     important:(BOOL)important
                       success:(void (^)(NSString *))success
                       failure:(void (^)(NSError *))failure {

    GCWCalendarEvent *newEvent = [GCWCalendar createEventWithTitle:title
                                                          location:location
                                           attendeesEmailAddresses:attendeesEmailAddresses
                                                       description:description
                                                              date:date
                                                          duration:duration];
    newEvent.isImportant = important;
    
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar addEvent:newEvent
                        toCalendar:calendarId
                           success:^(NSString *eventId) {
        newEvent.identifier = eventId;
        newEvent.calendarId = calendarId;

        if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidCreateEvent:)]) {
            [weakSelf.delegate calendarServiceDidCreateEvent:newEvent];
        }
        success(eventId);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)createRecurringEventForCalendar:(NSString *)calendarId
                              withTitle:(NSString *)title
                             recurrence:(NSArray<NSString *> *)recurrence
                               location:(NSString *)location
                attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                            description:(NSString *)description
                                   date:(NSDate *)date
                               duration:(NSInteger)duration
                                success:(void (^)(NSString *))success
                                failure:(void (^)(NSError *))failure {
    GCWCalendarEvent *newEvent = [GCWCalendar createEventWithTitle:title
                                                          location:location
                                           attendeesEmailAddresses:attendeesEmailAddresses
                                                       description:description
                                                              date:date
                                                          duration:duration];
    newEvent.recurrence = recurrence;
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar addEvent:newEvent
                        toCalendar:calendarId
                           success:^(NSString *eventId) {
        newEvent.identifier = eventId;
        newEvent.calendarId = calendarId;

        if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidCreateEvent:)]) {
            [weakSelf.delegate calendarServiceDidCreateEvent:newEvent];
        }
        success(eventId);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)updateEvent:(GCWCalendarEvent *)event
        forCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {

    __weak GCWCalendarService *weakSelf = self;
    [self.calendar updateEvent:event
                           inCalendar:calendarId
                              success:^{
        if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidUpdateEvent:)]) {
            [weakSelf.delegate calendarServiceDidUpdateEvent:event];
        }
        success();
    } failure:^(NSError *error) {
        // Precondition failed; resource is already changed, get the latest version and retry updating
        if (error.code == 412) {
            [self getEventForCalendar:event.calendarId
                              eventId:event.identifier
                              success:^(GCWCalendarEvent *updatedEvent) {
                event.ETag = updatedEvent.ETag;
                [self.calendar updateEvent:event
                                       inCalendar:event.calendarId
                                          success:^{
                    success();
                } failure:^(NSError *error) {
                    failure(error);
                }];
            } failure:^(NSError *error) {
                failure(error);
            }];
        } else {
            failure(error);
        }
    }];
}

- (void)deleteEvent:(NSString *)eventId
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure {
    [self removeEventFromCache:eventId];

    __weak GCWCalendarService *weakSelf = self;
    [self.calendar deleteEvent:eventId
                         fromCalendar:calendarId
                              success:^{
        if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidDeleteEvent:forCalendar:)]) {
            [weakSelf.delegate calendarServiceDidDeleteEvent:eventId forCalendar:calendarId];
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)getEventForCalendar:(NSString *)calendarId
                    eventId:(NSString *)eventId
                    success:(void (^)(GCWCalendarEvent *))success
                    failure:(void (^)(NSError *))failure {
    [self.calendar getEventForCalendar:calendarId
                                      eventId:eventId
                                      success:^(GCWCalendarEvent *event) {
        success(event);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)addEventToCache:(GCWCalendarEvent *)event {
    self.calendar.calendarEvents[event.identifier] = event;
}

- (void)removeEventFromCache:(NSString *)eventId {
    [self.calendar.calendarEvents removeObjectForKey:eventId];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"recurringEventId == %@", eventId];
    NSArray *filteredArray = [self.calendar.calendarEvents.allValues filteredArrayUsingPredicate:predicate];

    if (filteredArray.count) {
        for (GCWCalendarEvent *event in filteredArray) {
            [self.calendar.calendarEvents removeObjectForKey:event.identifier];
        }
    }
}

- (void)saveState {
    [self.calendar saveState];
}

@end
