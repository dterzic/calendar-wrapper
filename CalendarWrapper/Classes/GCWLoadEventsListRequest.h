#import <UIKit/UIKit.h>

@protocol CalendarAuthorizationProtocol;

@interface GCWLoadEventsListRequest : NSObject

@property (nonatomic, strong, nonnull, readonly) id<CalendarAuthorizationProtocol> authorizationManager;
@property (nonatomic, nonnull, readonly) NSDictionary *calendarUsers;
@property (nonatomic, nonnull, readonly) NSDictionary *calendarEntries;

- (instancetype _Nullable)initWithCalendarEntries:(NSDictionary *_Nonnull)calendarEntries
                             authorizationManager:(id<CalendarAuthorizationProtocol> _Nonnull)authorizationManager
                                    calendarUsers:(NSDictionary *_Nonnull)calendarUsers;

- (void)startFrom:(NSDate *_Nonnull)startDate
          endDate:(NSDate *_Nonnull)endDate
           filter:(NSString *_Nonnull)filter
          success:(void (^_Nullable)(NSArray *_Nonnull))success
          failure:(void (^_Nullable)(NSError *_Nonnull))failure;

- (void)cancel;

@end
