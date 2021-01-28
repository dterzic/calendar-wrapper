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

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
                                        delegate:(id<CalendarServiceDelegate>)delegate
                                        calendar:(GCWCalendar *)calendar {
    self = [super init];
    if (self) {
        if (calendar == nil) {
            self.calendar = [[GCWCalendar alloc] initWithClientId:kClientID
                                                presentingViewController:presentingViewController
                                             authorizationManager:nil
                                                     userDefaults:nil];
        } else {
            self.calendar = calendar;
        }
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - CalendarServiceProtocol

- (NSString *)getCalendarOwner:(NSString *)calendarId {
    return [self.calendar getCalendarOwner:calendarId];
}

- (NSArray *)calendarEvents {
    return self.calendar.calendarEvents.allValues.eventsFlatMap;
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

- (NSNumber *)notificationPeriod {
    return self.calendar.notificationPeriod;
}

- (GCWCalendarEvent *)getCalendarEventWithId:(NSString *)eventId calendarId:(NSString *)calendarId {
    id item = self.calendar.calendarEvents[eventId];
    if ([item isKindOfClass:NSDictionary.class]) {
        NSDictionary *items = (NSDictionary *)item;
        GCWCalendarEvent *event = items[calendarId];
        return event;
    } else if ([item isKindOfClass:GCWCalendarEvent.class]) {
        GCWCalendarEvent *event = (GCWCalendarEvent *)item;
        return event;
    } else {
        assert("Unexpected calendar event type");
    }
    return nil;
}

- (void)setNotificationPeriod:(NSNumber *)notificationPeriod {
    self.calendar.notificationPeriod = notificationPeriod;
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

- (void)syncEventsOnSuccess:(void (^)(BOOL))success failure:(void (^)(NSError *))failure {
    NSDate *startDate = [NSDate dateFromNumberOfDaysSinceNow:daysInPast];
    NSDate *endDate = [NSDate dateFromNumberOfDaysSinceNow:daysInFuture];

    __weak GCWCalendarService *weakSelf = self;
    [self.calendar syncEventsFrom:startDate to:endDate success:^(NSDictionary *syncedEvents, NSArray *removedEvents) {
        for (GCWCalendarEvent *event in syncedEvents.allValues) {
            if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidSyncEvent:)]) {
                [weakSelf.delegate calendarServiceDidSyncEvent:event];
            }
        }
        for (GCWCalendarEvent *event in removedEvents) {
            if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidDeleteEvent:forCalendar:)]) {
                [weakSelf.delegate calendarServiceDidDeleteEvent:event.identifier forCalendar:event.calendarId];
            }
        }
        success(syncedEvents.count > 0 || removedEvents.count > 0);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (GCWCalendarEvent *)newEventForCalendar:(NSString *)calendarId
                                withTitle:(NSString *)title
                                 location:(NSString *)location
                  attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                              description:(NSString *)description
                                     date:(NSDate *)date
                                 duration:(NSInteger)duration
                       notificationPeriod:(NSNumber *)notificationPeriod
                                important:(BOOL)important {

    NSNumber *period = (notificationPeriod != nil) ? notificationPeriod : self.calendar.notificationPeriod;

    GCWCalendarEvent *newEvent = [GCWCalendar createEventWithTitle:title
                                                          location:location
                                           attendeesEmailAddresses:attendeesEmailAddresses
                                                       description:description
                                                              date:date
                                                          duration:duration
                                                notificationPeriod:period];
    newEvent.calendarId = calendarId;
    newEvent.isImportant = important;

    return newEvent;
}

- (void)createEventForCalendar:(NSString *)calendarId
                     withTitle:(NSString *)title
                      location:(NSString *)location
       attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                   description:(NSString *)description
                          date:(NSDate *)date
                      duration:(NSInteger)duration
            notificationPeriod:(NSNumber *)notificationPeriod
                     important:(BOOL)important
                       success:(void (^)(NSString *))success
                       failure:(void (^)(NSError *))failure {

    GCWCalendarEvent *newEvent = [self newEventForCalendar:calendarId
                                                 withTitle:title
                                                  location:location
                                   attendeesEmailAddresses:attendeesEmailAddresses
                                               description:description
                                                      date:date
                                                  duration:duration
                                        notificationPeriod:notificationPeriod
                                                 important:important];

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
                     notificationPeriod:(NSNumber *)notificationPeriod
                                success:(void (^)(NSString *))success
                                failure:(void (^)(NSError *))failure {

    NSNumber *period = (notificationPeriod != nil) ? notificationPeriod : self.calendar.notificationPeriod;

    GCWCalendarEvent *newEvent = [GCWCalendar createEventWithTitle:title
                                                          location:location
                                           attendeesEmailAddresses:attendeesEmailAddresses
                                                       description:description
                                                              date:date
                                                          duration:duration
                                                notificationPeriod:period];
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
    [self removeRecurringEvent:event.identifier];

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
            [self loadEventForCalendar:event.calendarId
                               eventId:event.identifier
                               success:^(GCWCalendarEvent *updatedEvent) {
                event.ETag = updatedEvent.ETag;
                [self.calendar updateEvent:event
                                       inCalendar:event.calendarId
                                          success:^{
                    if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidUpdateEvent:)]) {
                        [weakSelf.delegate calendarServiceDidUpdateEvent:event];
                    }
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

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *)events
               success:(void (^)(void))success
               failure:(void (^)(NSError *))failure {
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar batchAddEvents:events
                          success:^(NSArray<GCWCalendarEvent *> *clonedEvents) {
        for (GCWCalendarEvent *clonedEvent in clonedEvents) {
            if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidCreateEvent:)]) {
                [weakSelf.delegate calendarServiceDidCreateEvent:clonedEvent];
            }
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)batchUpdateEvents:(NSArray <GCWCalendarEvent *> *)events
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure {

    for (GCWCalendarEvent *event in events) {
        [self removeRecurringEvent:event.identifier];
    }
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar batchUpdateEvents:events
                             success:^{
        for (GCWCalendarEvent *event in events) {
            if ([weakSelf.delegate respondsToSelector:@selector(calendarServiceDidUpdateEvent:)]) {
                [weakSelf.delegate calendarServiceDidUpdateEvent:event];
            }
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)batchDeleteEvents:(NSArray <NSString *> *)eventIds
            fromCalendars:(NSArray <NSString *> *)calendarIds
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure {

    for(NSString *eventId in eventIds) {
        [self removeEventFromCache:eventId];
    }
    [self.calendar batchDeleteEvents:eventIds
                       fromCalendars:calendarIds
                             success:^{
        for(int index=0; index < eventIds.count; index++) {
            NSString *eventId = eventIds[index];
            NSString *calendarId = calendarIds[index];

            if ([self.delegate respondsToSelector:@selector(calendarServiceDidDeleteEvent:forCalendar:)]) {
                [self.delegate calendarServiceDidDeleteEvent:eventId forCalendar:calendarId];
            }
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)loadEventForCalendar:(NSString *)calendarId
                     eventId:(NSString *)eventId
                     success:(void (^)(GCWCalendarEvent *))success
                     failure:(void (^)(NSError *))failure {
    [self.calendar loadEventForCalendar:calendarId
                                eventId:eventId
                                success:^(GCWCalendarEvent *event) {
        success(event);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)loadRecurringEventsFor:(NSArray <GCWCalendarEvent *> *)events
                       success:(void (^)(NSArray <GCWCalendarEvent *> *))success
                       failure:(void (^)(NSError *))failure {

    NSMutableArray *recurringEvents = [NSMutableArray array];
    NSMutableArray *recurringEventIds = [NSMutableArray array];
    NSMutableArray *calendarIds = [NSMutableArray array];
    for(GCWCalendarEvent *event in events) {
        if (![recurringEventIds containsObject:event.recurringEventId]) {
            [recurringEventIds addObject:event.recurringEventId];
            [calendarIds addObject:event.calendarId];
        }
    }
    __block NSUInteger count = 0;
    for (int index=0; index < recurringEventIds.count; index++) {
        NSString *recurringEventId = recurringEventIds[index];
        NSString *calendarId = calendarIds[index];

        [self loadEventForCalendar:calendarId
                           eventId:recurringEventId
                           success:^(GCWCalendarEvent *recurringEvent) {
            [recurringEvents addObject:recurringEvent];

            if (count == recurringEventIds.count-1) {
                success([recurringEvents copy]);
            }
        } failure:^(NSError *error) {
            failure(error);
            return;
        }];
    }
}

- (void)saveState {
    [self.calendar saveState];
}

#pragma mark - Private

- (void)removeEventFromCache:(NSString *)eventId {
    [self.calendar.calendarEvents removeObjectForKey:eventId];
    [self removeRecurringEvent:eventId];
}

- (void)removeRecurringEvent:(NSString *)recurringEventId {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"recurringEventId == %@", recurringEventId];
    NSArray *filteredArray = [self.calendar.calendarEvents.allValues filteredArrayUsingPredicate:predicate];

    if (filteredArray.count) {
        for (GCWCalendarEvent *event in filteredArray) {
            [self.calendar.calendarEvents removeObjectForKey:event.identifier];
        }
    }
}

@end
