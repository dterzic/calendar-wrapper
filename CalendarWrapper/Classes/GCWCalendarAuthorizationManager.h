#import <UIKit/UIKit.h>
#import "GCWCalendar.h"

@protocol CalendarAuthorizationProtocol

- (GCWCalendarAuthorization *_Nullable)defaultAuthorization;
- (NSMutableArray<GCWCalendarAuthorization *> *_Nullable)getAuthorizations;
- (BOOL)canAuthorizeWithAuthorizationFromKeychain:(NSString *_Nonnull)keychainKey;
- (GCWCalendarAuthorization *_Nullable)getAuthorizationFromKeychain:(NSString *_Nonnull)keychainKey;
- (void)saveAuthorization:(GCWCalendarAuthorization *_Nonnull)authorization toKeychain:(NSString *_Nonnull)keychainKey;
- (void)removeAuthorization:(GCWCalendarAuthorization *_Nonnull)authorization fromKeychain:(NSString *_Nonnull)keychainKey;

@optional

+ (NSString *_Nullable)getKeychainKeyForAuthorization:(GCWCalendarAuthorization *_Nonnull)authorization;
+ (NSString *_Nullable)getKeychainKeyForUser:(NSString *_Nonnull)userID;

@end

@interface GCWCalendarAuthorizationManager : NSObject <CalendarAuthorizationProtocol>

@end
