#import "GCWUserAccount.h"

@implementation GCWUserAccount

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo {
    self = [super init];
    if (self) {
        _name = [userInfo valueForKey:@"name"];
    }
    return self;
}

@end
