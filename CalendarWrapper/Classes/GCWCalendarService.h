#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@class GCWCalendar;
@class GTLRCalendar_Event;
@class GCWCalendarEvent;
@class GCWPerson;
@class GCWLoadEventsListRequest;
@class GCWUserAccount;
@class GCWTaskList;

@protocol GCWServiceDelegate <NSObject>

@optional

- (void)gcwServiceDidCreateEvent:(GCWCalendarEvent *_Nonnull)event;
- (void)gcwServiceDidUpdateEvent:(GCWCalendarEvent *_Nonnull)event;
- (void)gcwServiceDidDeleteEvent:(NSString *_Nonnull)eventId forCalendar:(NSString *_Nonnull)calendarId;
- (void)gcwServiceDidSyncEvent:(GCWCalendarEvent *_Nonnull)event;

@end

@protocol CalendarServiceProtocol <NSObject>

@optional

@property (nonatomic, readonly) BOOL isConnected;
@property (nonatomic, readonly) BOOL hasSignup;
@property (nonatomic, readonly) NSDictionary *_Nullable userAccounts;
@property (nonatomic, readonly) NSDictionary *_Nullable accountEntries;
@property (nonatomic, readonly) NSDictionary *_Nullable calendarEntries;
@property (nonatomic, readonly) NSDictionary *_Nullable calendarSyncTokens;
@property (nonatomic, readonly) NSArray *_Nullable calendarEvents;
@property (nonatomic, readonly) BOOL calendarsInSync;
@property (nonatomic) NSNumber *_Nullable notificationPeriod;
@property (nonatomic, readonly) NSDictionary *_Nullable taskLists;

- (void)removeSyncTokenForCalendar:(NSString *_Nonnull)calendarId;

- (NSString *_Nullable)getCalendarOwnerId:(NSString *_Nonnull)calendarId;

- (GCWUserAccount *_Nullable)getCalendarOwner:(NSString *_Nonnull)calendarId;

- (GCWCalendarEvent *_Nullable)getCalendarEventWithId:(NSString *_Nonnull)eventId calendarId:(NSString *_Nullable)calendarId;

- (void)refreshAllTokensOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (BOOL)isAuthorizedFor:(GCWAuthorizationScope)scope;

- (void)setVisibility:(BOOL)visible forCalendar:(NSString *_Nonnull)calendarId;

- (BOOL)resumeAuthorizationFlowWithURL:(NSURL *_Nonnull)url;

- (void)loadAuthorizationsOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doLoginOnSuccess:(void (^_Nonnull)(void))success
                 failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doLogoutOnSuccess:(void (^_Nonnull)(void))success
                  failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doAuthorizationOnSuccess:(void (^_Nonnull)(void))success
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

- (GCWCalendarEvent *_Nullable)newTaskForCalendar:(NSString *_Nonnull)calendarId
                                       taskListId:(NSString *_Nonnull)taskListId
                                         withTitle:(NSString *_Nullable)title
                                          details:(NSString *_Nullable)details
                                              due:(NSDate *_Nonnull)due;

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
                              important:(BOOL)important
                                success:(void (^_Nonnull)(GCWCalendarEvent *_Nonnull))success
                                failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)updateEvent:(GTLRCalendar_Event *_Nonnull)event
        forCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nonnull)(void))success
            failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)updateFollowingEventsFor:(GCWCalendarEvent *_Nonnull)event
                     forCalendar:(NSString *_Nonnull)calendarId
                            from:(NSDate *_Nullable)startDate
                              to:(NSDate *_Nullable)endDate
                         success:(void (^_Nonnull)(void))success
                         failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)updateRecurringEventsFor:(NSArray<GCWCalendarEvent *> *_Nonnull)events
                           delta:(NSTimeInterval)delta
                         success:(void (^_Nonnull)(void))success
                         failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)deleteEvent:(NSString *_Nonnull)eventId
       fromCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nonnull)(void))success
            failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)deleteRecurringEvent:(NSString *_Nonnull)eventId
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

- (void)loadEventsListFrom:(NSDate *_Nonnull)startDate
                        to:(NSDate *_Nonnull)endDate
                    filter:(NSString *_Nullable)filter
                   success:(void (^_Nullable)(NSUInteger))success
                   failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (GCWLoadEventsListRequest *_Nullable)createEventsListRequest;

- (void)syncEventsFrom:(NSDate *_Nonnull)startDate
                    to:(NSDate *_Nonnull)endDate
               success:(void (^_Nonnull)(BOOL))success
               failure:(void (^_Nonnull)(NSError *_Nonnull))failure
              progress:(void (^_Nonnull)(CGFloat))progress;

- (void)loadEventForCalendar:(NSString *_Nonnull)calendarId
                     eventId:(NSString *_Nonnull)eventId
                     success:(void (^_Nonnull)(GCWCalendarEvent *_Nullable))success
                     failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadRecurringEventsFor:(NSArray <GCWCalendarEvent *> *_Nonnull)events
                       success:(void (^_Nonnull)(NSArray <GCWCalendarEvent *> *_Nullable))success
                       failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)getContactsFor:(NSString *_Nonnull)calendarId
               success:(void (^_Nonnull)(NSArray <GCWPerson *> *_Nonnull))success
               failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)getPeopleFor:(NSString *_Nonnull)calendarId
             success:(void (^_Nonnull)(NSArray <GCWPerson *> *_Nonnull))success
             failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadTaskListsOnSuccess:(void (^_Nonnull)(void))success
                       failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)insertTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(void))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)updateTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(void))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)deleteTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(void))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)moveTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
               toTaskList:(NSString *_Nonnull)taskListId
                  success:(void (^_Nullable)(void))success
                  failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)saveState;

- (void)clearEventsCache;

- (void)clearFetchedEventsBefore:(NSDate *_Nonnull)startDate after:(NSDate *_Nonnull)endDate;

@end


@interface GCWCalendarService : NSObject

@property (nonatomic, weak, nullable) id<GCWServiceDelegate> delegate;

- (instancetype _Nonnull)initWithPresentingViewController:(UIViewController *_Nonnull)presentingViewController
                                        delegate:(id<GCWServiceDelegate>_Nullable)delegate
                                        calendar:(GCWCalendar *_Nullable)calendar;

@end
