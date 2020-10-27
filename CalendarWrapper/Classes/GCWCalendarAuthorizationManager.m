#import "GCWCalendarAuthorizationManager.h"
#import "GCWCalendarAuthorization.h"

static NSString *const kCalendarWrapperAuthorizerKey = @"googleOAuthCodingKeyForCalendarWrapper";

@interface GCWCalendarAuthorizationManager ()

@property (nonatomic) NSMutableArray<GCWCalendarAuthorization *> *authorizations;

@end

@implementation GCWCalendarAuthorizationManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _authorizations = [NSMutableArray array];
    }
    return self;
}

+ (NSString *)getKeychainKeyForAuthorization:(GCWCalendarAuthorization *)authorization {
    return [NSString stringWithFormat:@"%@_%@", kCalendarWrapperAuthorizerKey, authorization.userID];
}

+ (NSString *)getKeychainKeyForUser:(NSString *)userID {
    return [NSString stringWithFormat:@"%@_%@", kCalendarWrapperAuthorizerKey, userID];
}


- (GCWCalendarAuthorization *)defaultAuthorization {
    return _authorizations[0];
}

- (NSMutableArray<GCWCalendarAuthorization *> *)getAuthorizations {
    return _authorizations;
}

- (void)saveAuthorization:(GCWCalendarAuthorization *)authorization toKeychain:(NSString *)keychainKey {
    [GTMAppAuthFetcherAuthorization saveAuthorization:authorization.fetcherAuthorization toKeychainForName:keychainKey];
    [_authorizations addObject:authorization];
}

- (void)removeAuthorization:(GCWCalendarAuthorization *)authorization fromKeychain:(NSString *)keychainKey {
    [GTMAppAuthFetcherAuthorization removeAuthorizationFromKeychainForName:keychainKey];
    [_authorizations removeObject:authorization];
}

- (GCWCalendarAuthorization *)getAuthorizationFromKeychain:(NSString *)keychainKey {
    GTMAppAuthFetcherAuthorization *fetcherAuthorization = [GTMAppAuthFetcherAuthorization authorizationFromKeychainForName:keychainKey];
    return [[GCWCalendarAuthorization alloc] initWithFetcherAuthorization:fetcherAuthorization];
}

- (BOOL)canAuthorizeWithAuthorizationFromKeychain:(NSString * _Nonnull)keychainKey {
    GTMAppAuthFetcherAuthorization *authorization = [GTMAppAuthFetcherAuthorization authorizationFromKeychainForName:keychainKey];
    return authorization.canAuthorize;
}


@end
