#import <UIKit/UIKit.h>

@class GCWCalendar;
@class GTLRCalendar_Event;
@class GCWCalendarEvent;

@protocol CalendarServiceDelegate <NSObject>

@optional

- (void)calendarServiceDidCreateEvent:(GCWCalendarEvent *)event;
- (void)calendarServiceDidUpdateEvent:(GCWCalendarEvent *)event;
- (void)calendarServiceDidDeleteEvent:(NSString *)eventId forCalendar:(NSString *)calendarId;
- (void)calendarServiceDidSyncEvent:(GCWCalendarEvent *)event;

@end

@protocol CalendarServiceProtocol <NSObject>

@optional

@property (nonatomic, readonly) BOOL hasSignup;
@property (nonatomic, readonly) NSDictionary *userAccounts;
@property (nonatomic, readonly) NSDictionary *accountEntries;
@property (nonatomic, readonly) NSDictionary *calendarEntries;
@property (nonatomic, readonly) NSArray *calendarEvents;
@property (nonatomic) NSNumber *notificationPeriod;

- (NSString *)getCalendarOwner:(NSString *)calendarId;

- (GCWCalendarEvent *)getCalendarEventWithId:(NSString *)eventId calendarId:(NSString *)calendarId;

- (void)setVisibility:(BOOL)visible forCalendar:(NSString *)calendarId;

- (BOOL)resumeAuthorizationFlowWithURL:(NSURL *)url;

- (void)loadAuthorizationsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure;

- (void)doLoginOnSuccess:(void (^)(void))success
                 failure:(void (^)(NSError *))failure;

- (void)loadCalendarListOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure;

- (GCWCalendarEvent *)newEventForCalendar:(NSString *)calendarId
                                withTitle:(NSString *)title
                                 location:(NSString *)location
                  attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                              description:(NSString *)description
                                     date:(NSDate *)date
                                 duration:(NSInteger)duration
                       notificationPeriod:(NSNumber *)notificationPeriod
                                important:(BOOL)important;

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
                       failure:(void (^)(NSError *))failure;

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
                                failure:(void (^)(NSError *))failure;

- (void)updateEvent:(GTLRCalendar_Event *)event
        forCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure;

- (void)deleteEvent:(NSString *)eventId
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure;

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *)events
               success:(void (^)(void))success
               failure:(void (^)(NSError *))failure;

- (void)batchUpdateEvents:(NSArray <GCWCalendarEvent *> *)events
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure;

- (void)batchDeleteEvents:(NSArray <NSString *> *)eventIds
            fromCalendars:(NSArray <NSString *> *)calendarIds
                  success:(void (^)(void))success
                  failure:(void (^)(NSError *))failure;

- (void)loadEventsOnSuccess:(void (^)(NSArray <GCWCalendarEvent *> *events, NSDictionary *calendarList))success
                    failure:(void (^)(NSError *))failure;

- (void)syncEventsOnSuccess:(void (^)(BOOL))success failure:(void (^)(NSError *))failure;

- (void)loadEventForCalendar:(NSString *)calendarId
                     eventId:(NSString *)eventId
                     success:(void (^)(GCWCalendarEvent *))success
                     failure:(void (^)(NSError *))failure;

- (void)loadRecurringEventsFor:(NSArray <GCWCalendarEvent *> *)events
                       success:(void (^)(NSArray <GCWCalendarEvent *> *))success
                       failure:(void (^)(NSError *))failure;

- (void)saveState;

@end


@interface GCWCalendarService : NSObject

@property (nonatomic, weak) id<CalendarServiceDelegate> delegate;

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController
                                        delegate:(id<CalendarServiceDelegate>)delegate
                                        calendar:(GCWCalendar *)calendar;

@end
