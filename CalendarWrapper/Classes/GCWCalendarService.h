#import <UIKit/UIKit.h>

@class GCWCalendar;
@class GTLRCalendar_Event;
@class GCWCalendarEvent;

@protocol CalendarServiceDelegate <NSObject>

@optional

- (void)calendarServiceDidCreateEvent:(GCWCalendarEvent *_Nonnull)event;
- (void)calendarServiceDidUpdateEvent:(GCWCalendarEvent *_Nonnull)event;
- (void)calendarServiceDidDeleteEvent:(NSString *_Nonnull)eventId forCalendar:(NSString *_Nonnull)calendarId;
- (void)calendarServiceDidSyncEvent:(GCWCalendarEvent *_Nonnull)event;

@end

@protocol CalendarServiceProtocol <NSObject>

@optional

@property (nonatomic, readonly) BOOL hasSignup;
@property (nonatomic, readonly) NSDictionary *_Nullable userAccounts;
@property (nonatomic, readonly) NSDictionary *_Nullable accountEntries;
@property (nonatomic, readonly) NSDictionary *_Nullable calendarEntries;
@property (nonatomic, readonly) NSArray *_Nullable calendarEvents;
@property (nonatomic) NSNumber *_Nullable notificationPeriod;

- (NSString *_Nullable)getCalendarOwner:(NSString *_Nonnull)calendarId;

- (GCWCalendarEvent *_Nullable)getCalendarEventWithId:(NSString *_Nonnull)eventId calendarId:(NSString *_Nullable)calendarId;

- (void)setVisibility:(BOOL)visible forCalendar:(NSString *_Nonnull)calendarId;

- (BOOL)resumeAuthorizationFlowWithURL:(NSURL *_Nonnull)url;

- (void)loadAuthorizationsOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doLoginOnSuccess:(void (^_Nonnull)(void))success
                 failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadCalendarListOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (GCWCalendarEvent *_Nullable)newEventForCalendar:(NSString *_Nonnull)calendarId
                                withTitle:(NSString *_Nonnull)title
                                 location:(NSString *_Nullable)location
                  attendeesEmailAddresses:(NSArray<NSString *> *_Nullable)attendeesEmailAddresses
                              description:(NSString *_Nullable)description
                                     date:(NSDate *_Nonnull)date
                                 duration:(NSInteger)duration
                       notificationPeriod:(NSNumber *_Nonnull)notificationPeriod
                                important:(BOOL)important;

- (void)createEventForCalendar:(NSString *_Nonnull)calendarId
                     withTitle:(NSString *_Nonnull)title
                      location:(NSString *_Nullable)location
       attendeesEmailAddresses:(NSArray<NSString *> *_Nullable)attendeesEmailAddresses
                   description:(NSString *_Nullable)description
                          date:(NSDate *_Nonnull)date
                      duration:(NSInteger)duration
            notificationPeriod:(NSNumber *_Nonnull)notificationPeriod
                     important:(BOOL)important
                       success:(void (^_Nonnull)(GCWCalendarEvent *_Nonnull))success
                       failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)createRecurringEventForCalendar:(NSString *_Nonnull)calendarId
                              withTitle:(NSString *_Nonnull)title
                             recurrence:(NSArray<NSString *> *_Nullable)recurrence
                               location:(NSString *_Nullable)location
                attendeesEmailAddresses:(NSArray<NSString *> *_Nullable)attendeesEmailAddresses
                            description:(NSString *_Nullable)description
                                   date:(NSDate *_Nonnull)date
                               duration:(NSInteger)duration
                     notificationPeriod:(NSNumber *_Nonnull)notificationPeriod
                                success:(void (^_Nonnull)(GCWCalendarEvent *_Nonnull))success
                                failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)updateEvent:(GTLRCalendar_Event *_Nonnull)event
        forCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nonnull)(void))success
            failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)deleteEvent:(NSString *_Nonnull)eventId
       fromCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nonnull)(void))success
            failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *_Nonnull)events
               success:(void (^_Nonnull)(NSArray<GCWCalendarEvent *> *_Nonnull))success
               failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)batchUpdateEvents:(NSArray <GCWCalendarEvent *> *_Nonnull)events
                  success:(void (^_Nonnull)(void))success
                  failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)batchDeleteEvents:(NSArray <NSString *> *_Nonnull)eventIds
            fromCalendars:(NSArray <NSString *> *_Nonnull)calendarIds
                  success:(void (^_Nonnull)(void))success
                  failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadEventsOnSuccess:(void (^_Nonnull)(NSArray <GCWCalendarEvent *> *_Nullable events, NSDictionary *_Nullable calendarList))success
                    failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)syncEventsOnSuccess:(void (^_Nonnull)(BOOL))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadEventForCalendar:(NSString *_Nonnull)calendarId
                     eventId:(NSString *_Nonnull)eventId
                     success:(void (^_Nonnull)(GCWCalendarEvent *_Nullable))success
                     failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadRecurringEventsFor:(NSArray <GCWCalendarEvent *> *_Nonnull)events
                       success:(void (^_Nonnull)(NSArray <GCWCalendarEvent *> *_Nullable))success
                       failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)saveState;

- (void)clearEventsCache;

@end


@interface GCWCalendarService : NSObject

@property (nonatomic, weak, nullable) id<CalendarServiceDelegate> delegate;

- (instancetype _Nonnull)initWithPresentingViewController:(UIViewController *_Nonnull)presentingViewController
                                        delegate:(id<CalendarServiceDelegate>_Nullable)delegate
                                        calendar:(GCWCalendar *_Nullable)calendar;

@end
