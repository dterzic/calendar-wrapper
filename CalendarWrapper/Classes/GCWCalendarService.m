#import "GCWCalendarService.h"
#import "GCWCalendarEntry.h"
#import "GCWCalendarEvent.h"
#import "GCWLoadEventsListRequest.h"
#import "GCWLoadEventsOperation.h"
#import "GCWSyncEventsOperation.h"

#import "NSDictionary+GCWCalendarEvent.h"
#import "NSArray+GCWEventsSorting.h"
#import "NSDictionary+GCWCalendar.h"
#import "NSDate+GCWDate.h"
#import "NSError+GCWCalendar.h"
#import "UIColor+MNTColor.h"


static NSString * const kClientID = @"235185111239-ubk6agijf4d4vq8s4fseradhn2g66r5s.apps.googleusercontent.com";
static NSString * const kCalendarFilterKey = @"calendarWrapperCalendarFilterKey";

@interface GCWCalendarService () <CalendarServiceProtocol>

@property (nonatomic) GCWCalendar *calendar;
@property (nonatomic) NSOperationQueue *eventsOperationQueue;

@end

@implementation GCWCalendarService

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
                                        delegate:(id<GCWServiceDelegate>)delegate
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
        self.eventsOperationQueue = [[NSOperationQueue alloc] init];
        self.eventsOperationQueue.maxConcurrentOperationCount = 1;
        self.delegate = delegate;
    }
    return self;
}

#pragma mark - CalendarServiceProtocol

- (void)removeSyncTokenForCalendar:(NSString *)calendarId {
    [self removeEventsForCalendar:calendarId];
    [self.calendar.calendarSyncTokens removeObjectForKey:calendarId];
}

- (NSString *)getCalendarOwner:(NSString *)calendarId {
    return [self.calendar getCalendarOwner:calendarId];
}

- (NSArray *)calendarEvents {
    return self.calendar.calendarEvents.allValues.eventsFlatMap;
}

- (NSDictionary *)calendarSyncTokens {
    return self.calendar.calendarSyncTokens;
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

- (BOOL)isConnected {
    return self.calendar.calendarEntries.count > 0;
}

- (BOOL)hasSignup {
    return self.calendar.userAccounts.count > 0;
}

- (void)setCalendarListEntries:(NSDictionary *)calendarListEntries {
    self.calendar.calendarEntries = calendarListEntries;
}

- (BOOL)calendarsInSync {
    return self.calendar.calendarsInSync;
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

- (void)loadEventsListFrom:(NSDate *)startDate
                        to:(NSDate *)endDate
                    filter:(NSString *)filter
                   success:(void (^)(NSUInteger))success
                   failure:(void (^)(NSError * _Nonnull))failure {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);

            GCWLoadEventsOperation *loadEventsOperation = [[GCWLoadEventsOperation alloc] initWithCalendar:self.calendar
                                                                                                 startDate:startDate
                                                                                                   endDate:endDate
                                                                                                    filter:filter];
            __weak GCWLoadEventsOperation *weakOperation = loadEventsOperation;
            loadEventsOperation.completionBlock = ^{
                if (weakOperation.error != nil) {
                    failure(weakOperation.error);
                    dispatch_group_leave(group);
                    return;
                }
                if (filter.length) {
                    success(weakOperation.filteredEventsCount);
                } else {
                    success(weakOperation.loadedEvents.count + weakOperation.removedEvents.count);
                }
                dispatch_group_leave(group);
            };
            [self.eventsOperationQueue addOperations:@[loadEventsOperation] waitUntilFinished:YES];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }
    });
}

- (GCWLoadEventsListRequest *)createEventsListRequest {
    return [self.calendar createEventsListRequest];
}

- (void)syncEventsFrom:(NSDate *)startDate
                    to:(NSDate *)endDate
               success:(void (^)(BOOL))success
               failure:(void (^)(NSError *))failure
              progress:(void (^)(CGFloat))progress {

    __weak GCWCalendarService *weakSelf = self;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized (self) {
            dispatch_group_t group = dispatch_group_create();
            dispatch_group_enter(group);

            GCWSyncEventsOperation *syncEventsOperation = [[GCWSyncEventsOperation alloc] initWithCalendar:self.calendar
                                                                                                 startDate:startDate
                                                                                                   endDate:endDate
                                                                                                  progress:^(CGFloat percent) {
                progress(percent);
            }];
            __weak GCWSyncEventsOperation *weakOperation = syncEventsOperation;
            syncEventsOperation.completionBlock = ^{
                if (weakOperation.error != nil) {
                    failure(weakOperation.error);
                    dispatch_group_leave(group);
                    return;
                }
                for (GCWCalendarEvent *event in weakOperation.syncedEvents.allValues) {
                    if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidSyncEvent:)]) {
                        [weakSelf.delegate gcwServiceDidSyncEvent:event];
                    }
                }
                for (GCWCalendarEvent *event in weakOperation.removedEvents) {
                    if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
                        [weakSelf.delegate gcwServiceDidDeleteEvent:event.identifier forCalendar:event.calendarId];
                    }
                }
                // Remove expired sync tokens from storage and wipe calendar events from cache.
                for (NSString *calendarId in weakOperation.expiredTokens) {
                    [weakSelf removeEventsForCalendar:calendarId];
                    [weakSelf.calendar.calendarSyncTokens removeObjectForKey:calendarId];
                }
                [weakSelf.calendar saveState];

                if (weakOperation.expiredTokens.count) {
                    failure([NSError createErrorWithCode:410 description:@"Sync token is no longer valid, a full sync is required."]);
                } else {
                    success(weakOperation.syncedEvents.count > 0 || weakOperation.removedEvents.count > 0);
                }
                dispatch_group_leave(group);
            };
            [self.eventsOperationQueue addOperations:@[syncEventsOperation] waitUntilFinished:YES];
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }
    });
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
                                                notificationPeriod:period
                                                         important:important];
    newEvent.calendarId = calendarId;

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
                       success:(void (^)(GCWCalendarEvent *))success
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
                    success:^(GCWCalendarEvent *event) {

        if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidCreateEvent:)]) {
            [weakSelf.delegate gcwServiceDidCreateEvent:event];
        }
        success(event);
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
                              important:(BOOL)important
                                success:(void (^)(GCWCalendarEvent *))success
                                failure:(void (^)(NSError *))failure {

    NSNumber *period = (notificationPeriod != nil) ? notificationPeriod : self.calendar.notificationPeriod;

    GCWCalendarEvent *newEvent = [GCWCalendar createEventWithTitle:title
                                                          location:location
                                           attendeesEmailAddresses:attendeesEmailAddresses
                                                       description:description
                                                              date:date
                                                          duration:duration
                                                notificationPeriod:period
                                                         important:important];
    newEvent.recurrence = recurrence;
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar addEvent:newEvent
                        toCalendar:calendarId
                           success:^(GCWCalendarEvent *event) {
        if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidCreateEvent:)]) {
            [weakSelf.delegate gcwServiceDidCreateEvent:event];
        }
        success(event);
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
        if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidUpdateEvent:)]) {
            [weakSelf.delegate gcwServiceDidUpdateEvent:event];
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
                    if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidUpdateEvent:)]) {
                        [weakSelf.delegate gcwServiceDidUpdateEvent:event];
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
        if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
            [weakSelf.delegate gcwServiceDidDeleteEvent:eventId forCalendar:calendarId];
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)updateFollowingEventsFor:(GCWCalendarEvent *)event
                     forCalendar:(NSString *)calendarId
                            from:(NSDate *)startDate
                              to:(NSDate *)endDate
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *))failure {

    [self.calendar loadRecurringEventInstancesFor:event.recurringEventId
                                         calendar:calendarId
                                             from:startDate
                                               to:nil
                                          success:^(NSArray *eventInstances) {

        if (eventInstances.count == 0) {
            success();
            return;
        }
        GCWCalendarEvent *firstInstance = eventInstances[0];

        NSTimeInterval startDelta = [startDate timeIntervalSinceDate:firstInstance.startDate];
        NSTimeInterval endDelta = [endDate timeIntervalSinceDate:firstInstance.endDate];

        for (GCWCalendarEvent *eventInstance in eventInstances) {
            eventInstance.summary = event.summary;
            eventInstance.recurrence = event.recurrence;
            eventInstance.startDate = [eventInstance.startDate dateByAddingSeconds:startDelta];
            eventInstance.endDate = [eventInstance.endDate dateByAddingSeconds:endDelta];
            eventInstance.attendeesEmailAddresses = event.attendeesEmailAddresses;
            eventInstance.location = event.location;
            eventInstance.notificationPeriod = event.notificationPeriod;
            eventInstance.descriptionProperty = event.descriptionProperty;
            eventInstance.isImportant = event.isImportant;
        }
        [self.calendar batchUpdateEvents:eventInstances
                                 success:^{
            success();
        } failure:^(NSError *error) {
            failure(error);
        }];
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)updateRecurringEventsFor:(NSArray<GCWCalendarEvent *> *)events
                           delta:(NSTimeInterval)delta
                         success:(void (^)(void))success
                         failure:(void (^)(NSError *))failure {

    __weak GCWCalendarService *weakSelf = self;
    [self loadRecurringEventsFor:events
                         success:^(NSArray<GCWCalendarEvent *> *recurringEvents) {
        for (GCWCalendarEvent *recurringEvent in recurringEvents) {
            [self removeEventFromCache:recurringEvent.identifier];

            [self.calendar deleteEvent:recurringEvent.identifier
                          fromCalendar:recurringEvent.calendarId
                               success:^{
                if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
                    [weakSelf.delegate gcwServiceDidDeleteEvent:recurringEvent.identifier forCalendar:recurringEvent.calendarId];
                }
                recurringEvent.startDate = [recurringEvent.startDate dateByAddingTimeInterval:delta];
                recurringEvent.endDate = [recurringEvent.endDate dateByAddingTimeInterval:delta];
                NSTimeInterval durationInMinutes = [recurringEvent.endDate timeIntervalSinceDate:recurringEvent.startDate] / 60;

                [self createRecurringEventForCalendar:recurringEvent.calendarId
                                            withTitle:recurringEvent.summary
                                           recurrence:recurringEvent.recurrence
                                             location:recurringEvent.location
                              attendeesEmailAddresses:recurringEvent.attendeesEmailAddresses
                                          description:recurringEvent.descriptionProperty
                                                 date:recurringEvent.startDate
                                             duration:durationInMinutes
                                   notificationPeriod:recurringEvent.notificationPeriod
                                            important:recurringEvent.isImportant
                                              success:^(GCWCalendarEvent *newEvent) {
                    success();
                } failure:^(NSError *error) {
                    failure(error);
                }];
            } failure:^(NSError *error) {
                failure(error);
            }];
        }
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)deleteRecurringEvent:(NSString *)eventId
                fromCalendar:(NSString *)calendarId
                     success:(void (^)(void))success
                     failure:(void (^)(NSError *))failure {

    [self removeEventFromCache:eventId];

    __weak GCWCalendarService *weakSelf = self;
    [self.calendar loadEventForCalendar:calendarId eventId:eventId success:^(GCWCalendarEvent *event) {
        [self.calendar deleteEvent:event.identifier
                      fromCalendar:calendarId
                           success:^{
            if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
                [weakSelf.delegate gcwServiceDidDeleteEvent:event.identifier forCalendar:calendarId];
            }
            success();
        } failure:^(NSError *error) {
            failure(error);
        }];
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *)events
               success:(void (^)(NSArray<GCWCalendarEvent *> *))success
               failure:(void (^)(NSError *))failure {
    __weak GCWCalendarService *weakSelf = self;
    [self.calendar batchAddEvents:events
                          success:^(NSArray<GCWCalendarEvent *> *clonedEvents) {
        for (GCWCalendarEvent *clonedEvent in clonedEvents) {
            if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidCreateEvent:)]) {
                [weakSelf.delegate gcwServiceDidCreateEvent:clonedEvent];
            }
        }
        success(clonedEvents);
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
            if ([weakSelf.delegate respondsToSelector:@selector(gcwServiceDidUpdateEvent:)]) {
                [weakSelf.delegate gcwServiceDidUpdateEvent:event];
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

    [self.calendar batchDeleteEvents:eventIds
                       fromCalendars:calendarIds
                             success:^{
        for(int index=0; index < eventIds.count; index++) {
            NSString *eventId = eventIds[index];
            NSString *calendarId = calendarIds[index];

            if ([self.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
                [self.delegate gcwServiceDidDeleteEvent:eventId forCalendar:calendarId];
            }
        }
        for(NSString *eventId in eventIds) {
            [self removeEventFromCache:eventId];
        }
        success();
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)batchDeleteRecurringEvents:(NSArray <NSString *> *)eventIds
                     fromCalendars:(NSArray <NSString *> *)calendarIds
                           success:(void (^)(void))success
                           failure:(void (^)(NSError *))failure {

    [self.calendar batchDeleteEvents:eventIds
                       fromCalendars:calendarIds
                             success:^{
        for(int index=0; index < eventIds.count; index++) {
            NSString *eventId = eventIds[index];
            NSString *calendarId = calendarIds[index];

            if ([self.delegate respondsToSelector:@selector(gcwServiceDidDeleteEvent:forCalendar:)]) {
                [self.delegate gcwServiceDidDeleteEvent:eventId forCalendar:calendarId];
            }
        }
        for(NSString *eventId in eventIds) {
            [self removeEventFromCache:eventId];
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

- (void)getContactsFor:(NSString *)calendarId
               success:(void (^)(NSArray <GCWPerson *> *))success
               failure:(void (^)(NSError *))failure {
    [self.calendar getContactsFor:calendarId success:^(NSArray<GCWPerson *> *persons) {
        success(persons);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)getPeopleFor:(NSString *)calendarId
             success:(void (^)(NSArray <GCWPerson *> *))success
             failure:(void (^)(NSError *))failure {
    [self.calendar getPeopleFor:calendarId success:^(NSArray<GCWPerson *> *persons) {
        success(persons);
    } failure:^(NSError *error) {
        failure(error);
    }];
}

- (void)saveState {
    [self.calendar saveState];
}

- (void)clearEventsCache {
    [self.calendar.calendarEvents removeAllObjects];
    [self.calendar.calendarSyncTokens removeAllObjects];
}

- (void)clearFetchedEventsBefore:(NSDate *)startDate after:(NSDate *)endDate {
    NSArray *events = [self.calendar getFetchedEventsBefore:startDate andAfter:endDate];
    [events enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *eventId = (NSString *)obj;
        [self.calendar.calendarEvents removeObjectForKey:eventId];
    }];
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

- (void)removeEventsForCalendar:(NSString *)calendarId {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"calendarId == %@", calendarId];
    NSArray *filteredArray = [self.calendar.calendarEvents.allValues filteredArrayUsingPredicate:predicate];
    if (filteredArray.count) {
        for (GCWCalendarEvent *event in filteredArray) {
            [self removeEventFromCache:event.identifier];
        }
    }
}

@end
