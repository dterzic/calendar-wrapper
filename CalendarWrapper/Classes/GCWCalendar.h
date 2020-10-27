#import <Foundation/Foundation.h>
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GoogleAPIClientForREST/GTLRCalendar.h>

@class GTLRCalendarService;
@class GCWCalendarEvent;
@class GCWCalendarAuthorization;

@protocol CalendarAuthorizationProtocol;

@interface GCWCalendar : NSObject

@property (nonatomic) GTLRCalendarService * _Nullable calendarService;
@property (nonatomic, strong, nullable) id<OIDExternalUserAgentSession> currentAuthorizationFlow;
@property (nonatomic, strong, nullable) id<CalendarAuthorizationProtocol> authorizationManager;
@property (nonatomic) NSDictionary * _Nullable calendarEntries;
@property (nonatomic) NSMutableDictionary * _Nullable calendarEvents;
@property (nonatomic) NSDictionary * _Nullable userAccounts;
@property (nonatomic, readonly) NSDictionary * _Nullable accountEntries;

- (instancetype _Nullable )initWithClientId:(NSString *_Nonnull)clientId
                   presentingViewController:(UIViewController *_Nullable)viewController
                       authorizationManager:(id<CalendarAuthorizationProtocol> _Nullable)authorizationManager
                               userDefaults:(NSUserDefaults *_Nullable)userDefaults;

- (NSString *_Nullable)getCalendarOwner:(NSString *_Nonnull)calendarId;

- (void)doLoginOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadAuthorizationsOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)saveState;

+ (GCWCalendarEvent *_Nullable)createEventWithTitle:(NSString *_Nonnull)title
                                           location:(NSString *_Nullable)location
                            attendeesEmailAddresses:(NSArray<NSString *> *_Nullable)attendeesEmailAddresses
                                        description:(NSString *_Nullable)description
                                               date:(NSDate *_Nonnull)date
                                           duration:(NSInteger)duration;

+ (GCWCalendarEvent *_Nonnull)cloneEvent:(GCWCalendarEvent *_Nonnull)event;

- (void)loadCalendarListsForRole:(NSString *_Nonnull)accessRole
                         success:(void (^_Nonnull)(NSDictionary *_Nonnull))success
                         failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)getEventForCalendar:(NSString *_Nonnull)calendarId
                    eventId:(NSString *_Nonnull)eventId
                    success:(void (^_Nullable)(GCWCalendarEvent *_Nonnull))success
                    failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)getEventsListForCalendar:(NSString *_Nonnull)calendarId
                       startDate:(NSDate *_Nonnull)startDate
                         endDate:(NSDate *_Nonnull)endDate
                      maxResults:(NSUInteger)maxResults
                         success:(void (^_Nullable)(NSDictionary *_Nonnull))success
                         failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)syncEventsFrom:(NSDate *_Nonnull)startDate
                    to:(NSDate *_Nonnull)endDate
               success:(void (^_Nullable)(NSDictionary *_Nonnull))success
               failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)addEvent:(GCWCalendarEvent *_Nonnull)event
      toCalendar:(NSString *_Nonnull)calendarId
         success:(void (^_Nullable)(NSString *_Nonnull))success
         failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)deleteEvent:(NSString *_Nonnull)eventId
       fromCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)updateEvent:(GCWCalendarEvent *_Nonnull)event
         inCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

@end
