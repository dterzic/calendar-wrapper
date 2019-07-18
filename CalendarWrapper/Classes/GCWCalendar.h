#import <Foundation/Foundation.h>
#import <GoogleSignIn/GoogleSignIn.h>
#import <GoogleAPIClientForREST/GTLRCalendar.h>

@class GTLRCalendarService;
@class GTLRCalendar_Event;

@class GCWCalendar;

@protocol GCWCalendarDelegate <NSObject>

- (void)calendar:(GCWCalendar *)calendar didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error;
- (void)calendar:(GCWCalendar *)calendar didDisconnectWithUser:(GIDGoogleUser *)user withError:(NSError *)error;
- (void)calendarLoginRequired:(GCWCalendar *)calendar;

@end

@interface GCWCalendar : NSObject <GIDSignInDelegate>

@property (nonatomic, weak) id<GCWCalendarDelegate> delegate;
@property (nonatomic) GTLRCalendarService *calendarService;
@property (nonatomic, readonly) BOOL isAuthenticated;

- (instancetype)initWithClientId:(NSString *)clientId delegate:(id<GCWCalendarDelegate>)delegate;

+ (GTLRCalendar_Event *)createEventWithTitle:(NSString *)title
                                    location:(NSString *)location
                                 description:(NSString *)description
                                        date:(NSDate *)date
                                    duration:(NSInteger)duration;
- (BOOL)silentSignin;

- (void)loadCalendarList:(void (^)(NSDictionary *))success failure:(void (^)(NSError *))failure;

- (void)getEventsListForCalendar:(NSString *)calendarId
                       startDate:(NSDate *)startDate
                         endDate:(NSDate *)endDate
                         success:(void (^)(NSDictionary *))success
                         failure:(void (^)(NSError *))failure;

- (void)addEvent:(GTLRCalendar_Event *)event
      toCalendar:(NSString *)calendarId
         success:(void (^)(NSString *))success
         failure:(void (^)(NSError *))failure;

- (void)deleteEvent:(NSString *)eventId
       fromCalendar:(NSString *)calendarId
            success:(void (^)(void))success
            failure:(void (^)(NSError *))failure;

@end
