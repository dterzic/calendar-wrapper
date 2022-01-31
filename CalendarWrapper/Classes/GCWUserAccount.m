#import "GCWUserAccount.h"

static NSString *const kCalendarUserAccountName = @"calendarWrapperCalendarUserAccountName";
static NSString *const kCalendarUserAccountEmail = @"calendarWrapperCalendarUserAccountEmail";

@implementation GCWUserAccount

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithUserInfo:(NSDictionary *)userInfo {
    self = [super init];
    if (self) {
        _name = [userInfo valueForKey:@"name"];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self != nil) {
        self.name = [coder decodeObjectForKey:kCalendarUserAccountName];
        self.email = [coder decodeObjectForKey:kCalendarUserAccountEmail];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.name forKey:kCalendarUserAccountName];
    [coder encodeObject:self.email forKey:kCalendarUserAccountEmail];
}

@end
