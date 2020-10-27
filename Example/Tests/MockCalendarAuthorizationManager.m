#import "MockCalendarAuthorizationManager.h"
#import "MockCalendarAuthorization.h"

@implementation MockCalendarAuthorizationManager

- (GCWCalendarAuthorization * _Nullable)defaultAuthorization {
    return nil;
}

- (GCWCalendarAuthorization * _Nullable)getAuthorizationFromKeychain:(NSString * _Nonnull)keychainKey {
    for (MockCalendarAuthorization *authorization in self.authorizations) {
        if ([keychainKey containsString:authorization.userID]) {
            return (GCWCalendarAuthorization *)authorization;
        }
    }
    return nil;
}

- (NSMutableArray<GCWCalendarAuthorization *> * _Nullable)getAuthorizations {
    return self.authorizations;
}

- (void)removeAuthorization:(GCWCalendarAuthorization * _Nonnull)authorization fromKeychain:(NSString * _Nonnull)keychainKey {
}

- (void)saveAuthorization:(GCWCalendarAuthorization * _Nonnull)authorization toKeychain:(NSString * _Nonnull)keychainKey {
}

- (BOOL)canAuthorizeWithAuthorizationFromKeychain:(NSString * _Nonnull)keychainKey {
    return self.canAuthorize;
}

@end
