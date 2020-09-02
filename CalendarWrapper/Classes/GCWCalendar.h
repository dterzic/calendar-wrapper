#import <Foundation/Foundation.h>
#import <AppAuth/AppAuth.h>
#import <GTMAppAuth/GTMAppAuth.h>
#import <GoogleAPIClientForREST/GTLRCalendar.h>

@class GTLRCalendarService;
@class GTLRCalendar_Event;

@class GCWCalendar;

@protocol GCWCalendarDelegate <NSObject>

- (void)calendarLoginRequired:(GCWCalendar *_Nullable)calendar;

@end

@interface GCWCalendar : NSObject

@property (nonatomic, weak) id<GCWCalendarDelegate> _Nullable delegate;
@property (nonatomic) GTLRCalendarService * _Nullable calendarService;
@property (nonatomic, nullable) NSMutableArray<GTMAppAuthFetcherAuthorization *> *authorizations;

- (instancetype _Nullable )initWithClientId:(NSString *_Nonnull)clientId
                   presentingViewController:(UIViewController *_Nullable)viewController
                                   delegate:(id<GCWCalendarDelegate>_Nullable)delegate;

- (void)doLoginOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;

- (void)loadAuthorizationsOnSuccess:(void (^_Nonnull)(void))success failure:(void (^_Nonnull)(NSError *_Nonnull))failure;
- (void)saveAuthorizations;

+ (GTLRCalendar_Event *_Nullable)createEventWithTitle:(NSString *_Nonnull)title
                                    location:(NSString *_Nullable)location
                                 description:(NSString *_Nullable)description
                                        date:(NSDate *_Nonnull)date
                                    duration:(NSInteger)duration;


- (void)loadCalendarLists:(void (^_Nullable)(NSDictionary *_Nonnull))success
                  failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)loadCalendarListForAuthorization:(GTMAppAuthFetcherAuthorization *_Nonnull)authorization
                                 success:(void (^_Nullable)(NSDictionary *_Nonnull))success
                                 failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)getEventsListForCalendar:(NSString *_Nonnull)calendarId
                       startDate:(NSDate *_Nonnull)startDate
                         endDate:(NSDate *_Nonnull)endDate
                      maxResults:(NSUInteger)maxResults
                         success:(void (^_Nullable)(NSDictionary *_Nonnull))success
                         failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)addEvent:(GTLRCalendar_Event *_Nonnull)event
      toCalendar:(NSString *_Nonnull)calendarId
         success:(void (^_Nullable)(NSString *_Nonnull))success
         failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)deleteEvent:(NSString *_Nonnull)eventId
       fromCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)updateEvent:(GTLRCalendar_Event *_Nonnull)event
         inCalendar:(NSString *_Nonnull)calendarId
            success:(void (^_Nullable)(void))success
            failure:(void (^_Nullable)(NSError *_Nonnull))failure;

@end
