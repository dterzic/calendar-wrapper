#import <Foundation/Foundation.h>
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GoogleAPIClientForREST/GTLRCalendar.h>
#import <GoogleAPIClientForREST/GTLRTasks.h>
#import <GoogleAPIClientForREST/GTLRPeopleService.h>
#import <GoogleAPIClientForREST/GTLRTasksService.h>

@class GTLRCalendarService;
@class GTLRPeopleServiceService;
@class GCWCalendarEvent;
@class GCWPerson;
@class GCWCalendarAuthorization;
@class GCWLoadEventsListRequest;
@class GCWUserAccount;
@class GCWTaskList;

@protocol CalendarAuthorizationProtocol;

typedef NS_ENUM(NSUInteger, GCWAuthorizationScope) {
    GCWAuthorizationScopeOpenId = 0,
    GCWAuthorizationScopeCalendar,
    GCWAuthorizationScopePeople,
    GCWAuthorizationScopeTasks
};

@interface GCWCalendar : NSObject

@property (nonatomic) GTLRCalendarService * _Nullable calendarService;
@property (nonatomic) GTLRPeopleServiceService* _Nullable peopleService;
@property (nonatomic) GTLRTasksService* _Nullable tasksService;
@property (nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;
@property (nonatomic, strong, nullable) id<CalendarAuthorizationProtocol> authorizationManager;
@property (nonatomic) NSDictionary * _Nullable calendarEntries;
@property (nonatomic) NSMutableDictionary * _Nullable calendarSyncTokens;
@property (nonatomic) NSMutableDictionary * _Nullable calendarEvents;
@property (nonatomic) NSMutableDictionary * _Nullable userAccounts;
@property (nonatomic, readonly) NSDictionary * _Nullable accountEntries;
@property (nonatomic, readonly) BOOL calendarsInSync;
@property (nonatomic) NSNumber *_Nonnull notificationPeriod;
@property (nonatomic) NSDictionary <NSString *, GCWTaskList *> * _Nullable taskLists;

- (instancetype _Nullable )initWithClientId:(NSString *_Nonnull)clientId
                   presentingViewController:(UIViewController *_Nullable)viewController
                       authorizationManager:(id<CalendarAuthorizationProtocol> _Nullable)authorizationManager
                               userDefaults:(NSUserDefaults *_Nullable)userDefaults;

- (NSString *_Nullable)getCalendarOwnerId:(NSString *_Nonnull)calendarId;

- (GCWUserAccount *_Nullable)getCalendarOwner:(NSString *_Nonnull)calendarId;

- (void)refreshAllTokensOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (BOOL)isAuthorizedFor:(GCWAuthorizationScope)scope;

- (void)doLoginOnSuccess:(void (^_Nonnull)(void))success
                 failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doLogoutOnSuccess:(void (^_Nonnull)(void))success
                  failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)doAuthorizationOnSuccess:(void (^_Nonnull)(void))success
                         failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadAuthorizationsOnSuccess:(void (^_Nonnull)(void))success
                            failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)saveState;

+ (GCWCalendarEvent *_Nullable)createEventWithTitle:(NSString *_Nonnull)title
                                           location:(NSString *_Nullable)location
                            attendeesEmailAddresses:(NSArray<NSString *> *_Nullable)attendeesEmailAddresses
                                        description:(NSString *_Nullable)description
                                               date:(NSDate *_Nonnull)date
                                           duration:(NSInteger)duration
                                 notificationPeriod:(NSNumber *_Nonnull)notificationPeriod
                                          important:(BOOL)important;

+ (GCWCalendarEvent *_Nullable)createTaskWithCalendar:(NSString *_Nonnull)calendarId
                                           taskListId:(NSString *_Nonnull)taskListId
                                                title:(NSString *_Nullable)title
                                              details:(NSString *_Nullable)details
                                                  due:(NSDate *_Nonnull)date
                                   notificationPeriod:(NSNumber *_Nonnull)notificationPeriod;

+ (GCWCalendarEvent *_Nonnull)cloneEvent:(GCWCalendarEvent *_Nonnull)event;

- (void)loadCalendarListsForRole:(NSString *_Nonnull)accessRole
                         success:(void (^_Nonnull)(NSDictionary *_Nonnull))success
                         failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadEventForCalendar:(NSString *_Nonnull)calendarId
                     eventId:(NSString *_Nonnull)eventId
                     success:(void (^_Nullable)(GCWCalendarEvent *_Nonnull))success
                     failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)loadEventsListFrom:(NSDate *_Nonnull)startDate
                        to:(NSDate *_Nonnull)endDate
                    filter:(NSString *_Nullable)filter
                   success:(void (^_Nullable)(NSDictionary *_Nonnull, NSArray *_Nonnull, NSUInteger, NSArray *_Nonnull))success
                   failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)loadRecurringEventInstancesFor:(NSString *_Nonnull)recurringEventId
                              calendar:(NSString *_Nonnull)calendarId
                                  from:(NSDate *_Nullable)startDate
                                    to:(NSDate *_Nullable)endDate
                               success:(void (^_Nullable)(NSArray *_Nonnull))success
                               failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (GCWLoadEventsListRequest *_Nullable)createEventsListRequest;

- (NSArray *_Nonnull)getFetchedEventsBefore:(NSDate *_Nonnull)startDate andAfter:(NSDate *_Nonnull)endDate;

- (void)syncEventsFrom:(NSDate *_Nonnull)startDate
                    to:(NSDate *_Nonnull)endDate
               success:(void (^_Nullable)(NSDictionary *_Nonnull, NSArray *_Nonnull, NSArray *_Nonnull, NSArray *_Nonnull))success
               failure:(void (^_Nullable)(NSError *_Nonnull))failure
              progress:(void (^_Nullable)(CGFloat))progress;

- (void)addEvent:(GCWCalendarEvent *_Nonnull)event
      toCalendar:(NSString *_Nonnull)calendarId
         success:(void (^_Nullable)(GCWCalendarEvent *_Nonnull))success
         failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)deleteEvent:(NSString *_Nonnull)eventId
       fromCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)updateEvent:(GCWCalendarEvent *_Nonnull)event
         inCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)batchAddEvents:(NSArray <GCWCalendarEvent *> *_Nonnull)events
               success:(void (^_Nullable)(NSArray<GCWCalendarEvent *> *_Nonnull))success
               failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)batchUpdateEvents:(NSArray <GCWCalendarEvent *> *_Nonnull)events
                  success:(void (^_Nullable)(void))success
                  failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)batchDeleteEvents:(NSArray <NSString *> *_Nonnull)eventIds
            fromCalendars:(NSArray <NSString *> *_Nonnull)calendarIds
                  success:(void (^_Nullable)(void))success
                  failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)getContactsFor:(NSString *_Nonnull)calendarId
               success:(void (^_Nullable)(NSArray <GCWPerson *> *_Nonnull))success
               failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)getPeopleFor:(NSString *_Nonnull)calendarId
             success:(void (^_Nullable)(NSArray <GCWPerson *> *_Nonnull))success
             failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)loadTaskListsOnSuccess:(void (^_Nullable)(NSDictionary *_Nullable))success
                       failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)getTaskForEvent:(GCWCalendarEvent *_Nonnull)event
                success:(void (^_Nullable)(GCWTaskList *_Nullable, GTLRTasks_Task *_Nullable))success
                failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)syncTasksOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)insertTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(NSString *_Nonnull))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)updateTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(void))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)deleteTaskWithEvent:(GCWCalendarEvent *_Nonnull)event
                    success:(void (^_Nullable)(void))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

@end
