#import "MockCalendarAuthorization.h"

@interface MockCalendarAuthorization ()

@property (nonatomic) NSString *userId;

@end

@implementation MockCalendarAuthorization

- (instancetype)initWithUserID:(NSString *)userID {
    self = [super init];
    if (self) {
        _userId = userID;
    }
    return self;
}

- (NSString *)userID {
    return _userId;
}

@end
