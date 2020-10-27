#import "GCWCalendarAuthorization.h"

@implementation GCWCalendarAuthorization

- (instancetype)initWithFetcherAuthorization:(GTMAppAuthFetcherAuthorization *)fetcherAuthorization
{
    self = [super init];
    if (self) {
        _fetcherAuthorization = fetcherAuthorization;
    }
    return self;
}

- (NSString *)userID {
    return self.fetcherAuthorization.userID;
}

@end
