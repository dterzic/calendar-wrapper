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

@property (nonatomic, readonly) NSDictionary *userAccounts;
@property (nonatomic, readonly) NSDictionary *accountEntries;
@property (nonatomic, readonly) NSDictionary *calendarEntries;
@property (nonatomic, readonly) NSDictionary *calendarEvents;

- (NSString *)getCalendarOwner:(NSString *)calendarId;

- (void)setVisibility:(BOOL)visible forCalendar:(NSString *)calendarId;

- (BOOL)resumeAuthorizationFlowWithURL:(NSURL *)url;

- (void)loadAuthorizationsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure;

- (void)doLoginOnSuccess:(void (^)(void))success
                 failure:(void (^)(NSError *))failure;

- (void)loadCalendarListOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure;

- (void)createEventForCalendar:(NSString *)calendarId
                     withTitle:(NSString *)title
                      location:(NSString *)location
       attendeesEmailAddresses:(NSArray<NSString *> *)attendeesEmailAddresses
                   description:(NSString *)description
                          date:(NSDate *)date
                      duration:(NSInteger)duration
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

- (void)loadEventsOnSuccess:(void (^)(NSArray <GCWCalendarEvent *> *events, NSDictionary *calendarList))success
                    failure:(void (^)(NSError *))failure;

- (void)syncEventsOnSuccess:(void (^)(void))success failure:(void (^)(NSError *))failure;

- (void)getEventForCalendar:(NSString *)calendarId
                    eventId:(NSString *)eventId
                    success:(void (^)(GCWCalendarEvent *))success
                    failure:(void (^)(NSError *))failure;

- (void)saveState;

@end


@interface GCWCalendarService : NSObject

@property (nonatomic, weak) id<CalendarServiceDelegate> delegate;

- (instancetype)initWithPresentingViewController:(UIViewController *)presentingViewController delegate:(id<CalendarServiceDelegate>)delegate;

@end
